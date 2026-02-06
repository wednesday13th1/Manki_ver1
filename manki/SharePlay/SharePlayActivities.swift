import Foundation
import GroupActivities

struct TurnCollabActivity: GroupActivity {
    static var activityIdentifier: String { "manki.turn-collab" }

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Manki コラボ"
        metadata.type = .generic
        metadata.subtitle = "ターン制コラボ"
        return metadata
    }
}

struct SetShareActivity: GroupActivity {
    static var activityIdentifier: String { "manki.set-share" }

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Manki セット共有"
        metadata.type = .generic
        metadata.subtitle = "単語セットを共有"
        return metadata
    }
}
