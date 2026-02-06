import Foundation
import GroupActivities
import Combine

@MainActor
final class SetSharePlayManager {
    static let shared = SetSharePlayManager()

    private var groupSession: GroupSession<SetShareActivity>?
    private var messenger: GroupSessionMessenger?
    private var sessionTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var stateCancellable: AnyCancellable?

    private var pendingData: Data?

    var onReceiveData: ((Data) -> Void)?
    var onStatus: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private init() {}

    func start() {
        startListeningForSessionsIfNeeded()
        onStatus?("SharePlay待機")
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
        stateCancellable = nil
        groupSession = nil
        messenger = nil
        onStatus?("SharePlay停止")
    }

    func send(_ data: Data) {
        pendingData = data
        Task { [weak self] in
            await self?.activateIfNeeded()
            await self?.flushPendingIfPossible()
        }
    }

    private func startListeningForSessionsIfNeeded() {
        guard sessionTask == nil else { return }
        sessionTask = Task { [weak self] in
            for await session in SetShareActivity.sessions() {
                self?.configureSession(session)
            }
        }
    }

    private func configureSession(_ session: GroupSession<SetShareActivity>) {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)

        stateCancellable = session.$state
            .sink { [weak self] state in
                guard let self else { return }
                if case .invalidated = state {
                    self.onStatus?("SharePlay終了")
                    self.groupSession = nil
                    self.messenger = nil
                }
            }

        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self, let messenger = self.messenger else { return }
            for await (data, _) in messenger.messages(of: Data.self) {
                self.onReceiveData?(data)
            }
        }

        session.join()
        onStatus?("SharePlay参加")

        Task { [weak self] in
            await self?.flushPendingIfPossible()
        }
    }

    private func activateIfNeeded() async {
        guard groupSession == nil else { return }
        let activity = SetShareActivity()
        let activation = await activity.prepareForActivation()
        switch activation {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
                onStatus?("SharePlay開始")
            } catch {
                onError?("SharePlay開始エラー: \(error.localizedDescription)")
            }
        case .activationDisabled:
            onError?("SharePlayを開始できません")
        case .cancelled:
            onStatus?("SharePlayキャンセル")
        @unknown default:
            onError?("SharePlay不明な状態")
        }
    }

    private func flushPendingIfPossible() async {
        guard let data = pendingData, let messenger = messenger else { return }
        do {
            try await messenger.send(data)
            pendingData = nil
            onStatus?("共有送信")
        } catch {
            onError?("送信エラー: \(error.localizedDescription)")
        }
    }
}
