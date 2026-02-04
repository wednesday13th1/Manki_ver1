import Foundation

actor HostTurnController {
    private let room: TurnRoomContext
    private var turnIndex: Int = 0
    private var submittedTurnIndex: Set<Int> = []
    private var timeline: [TurnReplayItem] = []

    init(room: TurnRoomContext) {
        self.room = room
    }

    var totalTurns: Int { room.players.count }

    func currentPlayerID() -> String {
        let idx = turnIndex % room.players.count
        return room.players[idx].id
    }

    func startTurn() -> TurnStart? {
        guard turnIndex < totalTurns else { return nil }
        return TurnStart(
            sessionID: room.sessionID,
            turnIndex: turnIndex,
            totalTurns: totalTurns,
            currentPlayerID: currentPlayerID(),
            prompt: room.word
        )
    }

    func accept(_ submit: TurnSubmit) -> Bool {
        guard submit.turnIndex == turnIndex else { return false }
        guard submit.playerID == currentPlayerID() else { return false }
        guard !submittedTurnIndex.contains(turnIndex) else { return false }
        submittedTurnIndex.insert(turnIndex)
        timeline.append(TurnReplayItem(
            turnIndex: submit.turnIndex,
            playerID: submit.playerID,
            text: submit.text,
            timestamp: submit.timestamp
        ))
        return true
    }

    func advanceTurn() -> TurnStart? {
        turnIndex += 1
        return startTurn()
    }

    func buildReplay() -> TurnReplayPayload {
        TurnReplayPayload(sessionID: room.sessionID, items: timeline)
    }
}
