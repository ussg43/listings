import Foundation
import SwiftData

// On-device database (SwiftData / SQLite). The Go API has no endpoints for
// saved items or meetups, so these live on the phone, like the web app's
// localStorage. Full CRUD: create, read (@Query), update (edit meetup), delete.

@Model
final class SavedListing {
    @Attribute(.unique) var listingID: String
    var title: String
    var savedAt: Date

    init(listingID: String, title: String, savedAt: Date = .now) {
        self.listingID = listingID
        self.title = title
        self.savedAt = savedAt
    }
}

@Model
final class MeetupPlan {
    @Attribute(.unique) var planID: UUID
    var listingID: String
    var listingTitle: String
    var date: Date
    var spot: String
    var notes: String
    var createdAt: Date

    init(listingID: String, listingTitle: String, date: Date, spot: String, notes: String = "") {
        self.planID = UUID()
        self.listingID = listingID
        self.listingTitle = listingTitle
        self.date = date
        self.spot = spot
        self.notes = notes
        self.createdAt = .now
    }
}
