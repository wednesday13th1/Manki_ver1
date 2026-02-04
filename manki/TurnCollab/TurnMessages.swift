import Foundation

enum TurnMessageType: String, Codable {
    case hello
    case lobbyState
    case startGame
    case turnStart
    case turnSubmit
    case turnTimeout
    case replay
    case error
}

struct TurnMessageEnvelope: Codable {
    let schemaVersion: Int
    let sessionID: String
    let messageID: String
    let senderID: String
    let timestamp: TimeInterval
    let type: TurnMessageType
    let payload: Data

    static func encode<T: Codable>(type: TurnMessageType,
                                   sessionID: String,
                                   senderID: String,
                                   payload: T) throws -> Data {
        let payloadData = try JSONEncoder().encode(payload)
        let envelope = TurnMessageEnvelope(
            schemaVersion: 1,
            sessionID: sessionID,
            messageID: UUID().uuidString,
            senderID: senderID,
            timestamp: Date().timeIntervalSince1970,
            type: type,
            payload: payloadData
        )
        return try JSONEncoder().encode(envelope)
    }

    static func decode(_ data: Data) throws -> TurnMessageEnvelope {
        try JSONDecoder().decode(TurnMessageEnvelope.self, from: data)
    }
}
