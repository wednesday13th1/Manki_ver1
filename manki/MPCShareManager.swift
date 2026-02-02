import Foundation
import MultipeerConnectivity

final class MPCShareManager: NSObject {
    static let shared = MPCShareManager()

    private let serviceType = "manki-share"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private lazy var session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
    private lazy var advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
    private lazy var browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)

    private var peers: [MCPeerID] = []
    private var pendingSends: [String: (peer: MCPeerID, data: Data)] = [:]

    var onPeersChanged: (([MCPeerID]) -> Void)?
    var onReceiveData: ((Data, MCPeerID) -> Void)?
    var onStatus: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private override init() {
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        onStatus?("近くの端末を探索中")
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        onStatus?("探索停止")
    }

    func availablePeers() -> [MCPeerID] {
        return peers
    }

    func send(_ data: Data, to peer: MCPeerID) {
        if session.connectedPeers.contains(peer) {
            do {
                try session.send(data, toPeers: [peer], with: .reliable)
                onStatus?("送信しました: \(peer.displayName)")
            } catch {
                onError?("送信エラー: \(error.localizedDescription)")
            }
            return
        }
        pendingSends[peer.displayName] = (peer, data)
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
        onStatus?("接続要求: \(peer.displayName)")
    }
}

extension MPCShareManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        if !peers.contains(peerID) {
            peers.append(peerID)
            onPeersChanged?(peers)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        peers.removeAll { $0 == peerID }
        onPeersChanged?(peers)
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        onError?("探索開始エラー: \(error.localizedDescription)")
    }
}

extension MPCShareManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
        onStatus?("接続許可: \(peerID.displayName)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        onError?("広告開始エラー: \(error.localizedDescription)")
    }
}

extension MPCShareManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            if let pending = pendingSends.removeValue(forKey: peerID.displayName) {
                send(pending.data, to: pending.peer)
            } else {
                onStatus?("接続: \(peerID.displayName)")
            }
        case .connecting:
            onStatus?("接続中: \(peerID.displayName)")
        case .notConnected:
            onStatus?("切断: \(peerID.displayName)")
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        onReceiveData?(data, peerID)
    }

    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {}

    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {}
}
