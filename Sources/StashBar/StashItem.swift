import Cocoa

/// A detected "other app's" menu-bar status icon currently sitting inside
/// the stash zone.
struct StashItem: Identifiable, Equatable {
    let id: CGWindowID
    let ownerName: String
    let ownerPID: pid_t
    let frame: CGRect // in the same global coordinate space CGEventPost expects

    static func == (lhs: StashItem, rhs: StashItem) -> Bool {
        lhs.id == rhs.id
    }
}
