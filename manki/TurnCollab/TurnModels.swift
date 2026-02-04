import Foundation

enum TurnRoomState {
    case idle
    case lobby
    case inTurn
    case replay
    case ended
}

enum TurnState {
    case waiting
    case active
    case submitted
    case timeout
}

struct TurnRoomContext {
    let sessionID: String
    let hostID: String
    let players: [TurnPlayer]
    let word: String
    let turnDurationSec: Int
}

struct TurnPlayer: Codable, Hashable {
    let id: String
    let name: String
    let isHost: Bool
}

struct TurnStart: Codable {
    let sessionID: String
    let turnIndex: Int
    let totalTurns: Int
    let currentPlayerID: String
    let prompt: String
}

struct TurnSubmit: Codable {
    let sessionID: String
    let turnIndex: Int
    let playerID: String
    let text: String
    let timestamp: TimeInterval
}

struct TurnReplayItem: Codable {
    let turnIndex: Int
    let playerID: String
    let text: String
    let timestamp: TimeInterval
}

struct TurnReplayPayload: Codable {
    let sessionID: String
    let items: [TurnReplayItem]
}

struct TurnLobbyState: Codable {
    let sessionID: String
    let players: [TurnPlayer]
    let word: String
    let turnDurationSec: Int
    let totalTurns: Int
}
