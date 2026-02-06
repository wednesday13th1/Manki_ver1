import Foundation
import UIKit
import GroupActivities
import Combine

@MainActor
final class TurnRoomViewModel: ObservableObject {
    @Published var roomState: TurnRoomState = .idle
    @Published var lobbyPlayers: [TurnPlayer] = []
    @Published var participantLabels: [String] = []
    @Published var currentTurn: TurnStart?
    @Published var replayItems: [TurnReplayItem] = []
    @Published var statusText: String = ""

    private let selfID: String
    private var sessionID: String = UUID().uuidString
    private var isHost: Bool = false
    private var roomContext: TurnRoomContext?
    private var hostController: HostTurnController?
    private var seenMessageIDs: Set<String> = []
    private var turnTimerTask: Task<Void, Never>?

    private var groupSession: GroupSession<TurnCollabActivity>?
    private var messenger: GroupSessionMessenger?
    private var sessionTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var stateCancellable: AnyCancellable?
    private var participantsCancellable: AnyCancellable?

    init(displayName: String? = nil) {
        self.selfID = displayName ?? UIDevice.current.name
        startListeningForSessionsIfNeeded()
    }

    func hostRoom(word: String, turnDurationSec: Int = 60) {
        isHost = true
        sessionID = UUID().uuidString
        let host = TurnPlayer(id: selfID, name: selfID, isHost: true)
        lobbyPlayers = [host]
        roomContext = TurnRoomContext(
            sessionID: sessionID,
            hostID: selfID,
            players: lobbyPlayers,
            word: word,
            turnDurationSec: turnDurationSec
        )
        hostController = HostTurnController(room: roomContext!)
        roomState = .lobby
        statusText = "SharePlay開始中"

        Task { [weak self] in
            await self?.activateSharePlayIfNeeded()
        }
    }

    func joinRoom() {
        isHost = false
        roomState = .lobby
        statusText = "SharePlay参加待ち"
        startListeningForSessionsIfNeeded()
    }

    func startGame() {
        guard isHost, let roomContext, let hostController else { return }
        Task {
            let lobby = TurnLobbyState(
                sessionID: roomContext.sessionID,
                players: lobbyPlayers,
                word: roomContext.word,
                turnDurationSec: roomContext.turnDurationSec,
                totalTurns: lobbyPlayers.count
            )
            await broadcast(lobby, type: .lobbyState)
            if let turn = await hostController.startTurn() {
                await broadcast(turn, type: .turnStart)
                await MainActor.run {
                    self.currentTurn = turn
                    self.roomState = .inTurn
                }
                startTurnTimer(duration: roomContext.turnDurationSec)
            }
        }
    }

    func submit(text: String) {
        guard let turn = currentTurn else { return }
        let payload = TurnSubmit(
            sessionID: sessionID,
            turnIndex: turn.turnIndex,
            playerID: selfID,
            text: text,
            timestamp: Date().timeIntervalSince1970
        )
        Task {
            await broadcast(payload, type: .turnSubmit)
            if isHost, let hostController {
                _ = await hostController.accept(payload)
                await handleHostAdvanceIfNeeded()
            }
        }
    }

    private func handleHostAdvanceIfNeeded() async {
        guard let hostController else { return }
        if let next = await hostController.advanceTurn() {
            await broadcast(next, type: .turnStart)
            await MainActor.run { self.currentTurn = next }
            startTurnTimer(duration: roomContext?.turnDurationSec ?? 60)
        } else {
            turnTimerTask?.cancel()
            let replay = await hostController.buildReplay()
            await broadcast(replay, type: .replay)
            await MainActor.run {
                self.replayItems = replay.items
                self.roomState = .replay
            }
        }
    }

    private func handleTurnTimeout() async {
        guard isHost, let turn = currentTurn else { return }
        let timeout = TurnSubmit(
            sessionID: sessionID,
            turnIndex: turn.turnIndex,
            playerID: turn.currentPlayerID,
            text: "",
            timestamp: Date().timeIntervalSince1970
        )
        await broadcast(timeout, type: .turnTimeout)
        if let hostController {
            _ = await hostController.accept(timeout)
            await handleHostAdvanceIfNeeded()
        }
    }

    private func startTurnTimer(duration: Int) {
        turnTimerTask?.cancel()
        turnTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000_000)
            await self?.handleTurnTimeout()
        }
    }

    private func broadcast<T: Codable>(_ payload: T, type: TurnMessageType) async {
        guard let messenger else {
            statusText = "SharePlay未接続"
            return
        }
        do {
            let data = try TurnMessageEnvelope.encode(type: type, sessionID: sessionID, senderID: selfID, payload: payload)
            try await messenger.send(data)
        } catch {
            statusText = "送信エラー"
        }
    }

    private func startListeningForSessionsIfNeeded() {
        guard sessionTask == nil else { return }
        sessionTask = Task { [weak self] in
            for await session in TurnCollabActivity.sessions() {
                self?.configureSession(session)
            }
        }
    }

    private func configureSession(_ session: GroupSession<TurnCollabActivity>) {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)
        seenMessageIDs.removeAll()

        stateCancellable = session.$state
            .sink { [weak self] state in
                guard let self else { return }
                if case .invalidated = state {
                    self.resetSession()
                }
            }

        participantsCancellable = session.$activeParticipants
            .sink { [weak self] participants in
                self?.updateParticipants(participants)
            }

        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self, let messenger = self.messenger else { return }
            for await (data, _) in messenger.messages(of: Data.self) {
                await self.handleIncoming(data)
            }
        }

        session.join()
        statusText = "SharePlay参加"
    }

    private func resetSession() {
        groupSession = nil
        messenger = nil
        participantsCancellable = nil
        stateCancellable = nil
        participantLabels = []
        statusText = "SharePlay終了"
        roomState = .idle
        turnTimerTask?.cancel()
    }

    private func updateParticipants<P: Hashable>(_ participants: Set<P>) {
        var labels: [String] = []
        if messenger != nil {
            labels.append("自分")
        }
        let others = Array(participants)
        if !others.isEmpty {
            let extra = others.enumerated().map { index, _ in
                "参加者 \(index + 1)"
            }
            labels.append(contentsOf: extra)
        }
        participantLabels = labels
    }

    private func handleIncoming(_ data: Data) async {
        do {
            let envelope = try TurnMessageEnvelope.decode(data)
            guard !seenMessageIDs.contains(envelope.messageID) else { return }
            seenMessageIDs.insert(envelope.messageID)

            switch envelope.type {
            case .lobbyState:
                let payload = try JSONDecoder().decode(TurnLobbyState.self, from: envelope.payload)
                lobbyPlayers = payload.players
                roomState = .lobby
            case .turnStart:
                let payload = try JSONDecoder().decode(TurnStart.self, from: envelope.payload)
                currentTurn = payload
                roomState = .inTurn
            case .turnSubmit, .turnTimeout:
                if isHost {
                    let payload = try JSONDecoder().decode(TurnSubmit.self, from: envelope.payload)
                    Task {
                        if let hostController, await hostController.accept(payload) {
                            await handleHostAdvanceIfNeeded()
                        }
                    }
                }
            case .replay:
                let payload = try JSONDecoder().decode(TurnReplayPayload.self, from: envelope.payload)
                replayItems = payload.items
                roomState = .replay
            default:
                break
            }
        } catch {
            statusText = "受信デコードエラー"
        }
    }

    private func activateSharePlayIfNeeded() async {
        guard groupSession == nil else { return }
        let activity = TurnCollabActivity()
        let activation = await activity.prepareForActivation()
        switch activation {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
            } catch {
                statusText = "SharePlay開始エラー"
            }
        case .activationDisabled:
            statusText = "SharePlayを開始できません"
        case .cancelled:
            statusText = "SharePlayキャンセル"
        @unknown default:
            statusText = "SharePlay不明な状態"
        }
    }
}
