import Foundation
import MultipeerConnectivity

protocol TurnPeerManagerDelegate: AnyObject {
    func peerManager(_ manager: TurnPeerManager, didReceive data: Data, from peer: MCPeerID)
    func peerManager(_ manager: TurnPeerManager, didChangeConnectedPeers peers: [MCPeerID])
    func peerManager(_ manager: TurnPeerManager, didFind peers: [MCPeerID])
}

final class TurnPeerManager: NSObject {
    static let serviceType = "manki-turn"

    let peerID: MCPeerID
    let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    weak var delegate: TurnPeerManagerDelegate?
    var shouldAcceptInvitation: ((MCPeerID) -> Bool)?
    private var foundPeers: [MCPeerID] = []

    init(displayName: String) {
        self.peerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func startHosting() {
        advertiser.startAdvertisingPeer()
    }

    func stopHosting() {
        advertiser.stopAdvertisingPeer()
    }

    func startBrowsing() {
        browser.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser.stopBrowsingForPeers()
        foundPeers.removeAll()
        delegate?.peerManager(self, didFind: [])
    }

    func invite(_ peer: MCPeerID) {
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    func send(_ data: Data, to peers: [MCPeerID], reliable: Bool = true) throws {
        let mode: MCSessionSendDataMode = reliable ? .reliable : .unreliable
        try session.send(data, toPeers: peers, with: mode)
    }

    func availablePeers() -> [MCPeerID] {
        foundPeers
    }
}

extension TurnPeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.delegate?.peerManager(self, didChangeConnectedPeers: session.connectedPeers)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        delegate?.peerManager(self, didReceive: data, from: peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

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

extension TurnPeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let accept = shouldAcceptInvitation?(peerID) ?? true
        invitationHandler(accept, accept ? session : nil)
    }
}

extension TurnPeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        if !foundPeers.contains(peerID) {
            foundPeers.append(peerID)
        }
        delegate?.peerManager(self, didFind: foundPeers)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        foundPeers.removeAll { $0 == peerID }
        delegate?.peerManager(self, didFind: foundPeers)
    }
}
