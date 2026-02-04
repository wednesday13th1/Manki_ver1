import Foundation
import MultipeerConnectivity
import Combine

@MainActor
final class TurnRoomViewModel: ObservableObject {
    @Published var roomState: TurnRoomState = .idle
    @Published var lobbyPlayers: [TurnPlayer] = []
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var currentTurn: TurnStart?
    @Published var replayItems: [TurnReplayItem] = []
    @Published var statusText: String = ""

    private let peerManager: TurnPeerManager
    private let selfID: String
    private var sessionID: String = UUID().uuidString
    private var isHost: Bool = false
    private var roomContext: TurnRoomContext?
    private var hostController: HostTurnController?
    private var seenMessageIDs: Set<String> = []
    private var turnTimerTask: Task<Void, Never>?

    init(displayName: String = UIDevice.current.name) {
        self.peerManager = TurnPeerManager(displayName: displayName)
        self.selfID = peerManager.peerID.displayName
        self.peerManager.shouldAcceptInvitation = { [weak self] _ in
            guard let self else { return false }
            return self.roomState == .lobby || self.roomState == .idle
        }
        peerManager.delegate = self
    }

    func hostRoom(word: String, turnDurationSec: Int = 60) {
        isHost = true
        sessionID = UUID().uuidString
        peerManager.startHosting()
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
        statusText = "ホストとして待機中"
    }

    func joinRoom() {
        isHost = false
        peerManager.startBrowsing()
        roomState = .lobby
        statusText = "近くのホストを検索中"
    }

    func invite(_ peer: MCPeerID) {
        peerManager.invite(peer)
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
        guard !peerManager.session.connectedPeers.isEmpty else { return }
        do {
            let data = try TurnMessageEnvelope.encode(type: type, sessionID: sessionID, senderID: selfID, payload: payload)
            try peerManager.send(data, to: peerManager.session.connectedPeers)
        } catch {
            statusText = "送信エラー"
        }
    }
}

extension TurnRoomViewModel: TurnPeerManagerDelegate {
    func peerManager(_ manager: TurnPeerManager, didReceive data: Data, from peer: MCPeerID) {
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

    func peerManager(_ manager: TurnPeerManager, didChangeConnectedPeers peers: [MCPeerID]) {
        connectedPeers = peers
        if isHost {
            let host = TurnPlayer(id: selfID, name: selfID, isHost: true)
            let others = peers.map { TurnPlayer(id: $0.displayName, name: $0.displayName, isHost: false) }
            lobbyPlayers = [host] + others
            if var context = roomContext {
                context = TurnRoomContext(sessionID: context.sessionID,
                                          hostID: context.hostID,
                                          players: lobbyPlayers,
                                          word: context.word,
                                          turnDurationSec: context.turnDurationSec)
                roomContext = context
                hostController = HostTurnController(room: context)
            }
            if roomState == .lobby, let context = roomContext {
                Task {
                    let lobby = TurnLobbyState(sessionID: context.sessionID,
                                               players: lobbyPlayers,
                                               word: context.word,
                                               turnDurationSec: context.turnDurationSec,
                                               totalTurns: lobbyPlayers.count)
                    await broadcast(lobby, type: .lobbyState)
                }
            }
        }
    }

    func peerManager(_ manager: TurnPeerManager, didFind peers: [MCPeerID]) {
        availablePeers = peers
    }
}
