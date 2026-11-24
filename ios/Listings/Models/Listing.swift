import Foundation

/// Mirrors `store.ListingType` in the Go backend.
enum ListingType: String, Codable, CaseIterable, Identifiable {
    case sale, trade, giveaway

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sale: "For sale"
        case .trade: "Trade"
        case .giveaway: "Free"
        }
    }
}

/// Mirrors `store.Condition` in the Go backend.
enum ItemCondition: String, Codable, CaseIterable, Identifiable {
    case new, great, good, fair, poor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: "New"
        case .great: "Like new"
        case .good: "Good"
        case .fair: "Fair"
        case .poor: "Poor"
        }
    }
}

/// Mirrors `store.ListingStatus` in the Go backend.
enum ListingStatus: String, Codable, CaseIterable, Identifiable {
    case available, pending, sold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .available: "Available"
        case .pending: "Pending"
        case .sold: "Sold"
        }
    }
}

/// A listing as returned by `GET /v1/listings`.
struct Listing: Codable, Identifiable, Hashable {
    let id: String
    let userID: String
    var title: String
    var description: String
    var type: ListingType
    var condition: ItemCondition
    var status: ListingStatus
    /// Photo URLs. The server sends absolute URLs when `API_BASE_URL` is set,
    /// otherwise paths such as `/v1/photos/<file>`.
    var photos: [String]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, type, condition, status, photos
        case userID = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isSample: Bool { id.hasPrefix("sample-") }

    /// Text for the badge on a listing card.
    var badgeText: String { status == .available ? type.label : status.label }
}

/// The editable fields of a listing, sent as multipart form fields.
struct ListingDraft {
    var title = ""
    var description = ""
    var type: ListingType = .sale
    var condition: ItemCondition = .good
    var status: ListingStatus = .available

    init() {}

    init(listing: Listing) {
        title = listing.title
        description = listing.description
        type = listing.type
        condition = listing.condition
        status = listing.status
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Matches the limits enforced by `validateListing` on the server.
    var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Add a title." }
        if trimmedTitle.utf8.count > 160 { return "Titles can be at most 160 characters." }
        if description.utf8.count > 5000 { return "Descriptions can be at most 5,000 characters." }
        return nil
    }
}

enum MeetingSpot {
    static let all = ["Union", "West Village Commons", "Cook Library", "Glen Dining Hall"]
}

extension Listing {
    /// Shown when the API can't be reached, so the app still demos offline.
    /// Photos use the `sample:` scheme, which resolves to images in the app bundle.
    static let samples: [Listing] = {
        let rows: [(String, ListingType, ItemCondition, String)] = [
            ("Retro Runner Sneakers", .sale, .great,
             "Cream and black runners, US 10. Worn twice and includes the original box and spare laces."),
            ("Workwear Chore Coat", .sale, .good,
             "Rust canvas chore coat with three front pockets. Size medium."),
            ("Compact Digital Camera", .sale, .good,
             "Pocket-sized point-and-shoot camera with a battery, charger and SD card."),
            ("Canvas Daypack", .trade, .great,
             "Forest green canvas daypack with a padded laptop sleeve. Open to trading for a small duffel."),
            ("Mushroom Table Lamp", .sale, .great,
             "Warm orange table lamp in working condition. A bulb is included."),
            ("Steel Field Watch", .giveaway, .fair,
             "Stainless steel field watch with a black dial. It needs a fresh battery."),
        ]
        let now = Date()
        return rows.enumerated().map { index, row in
            Listing(
                id: "sample-\(index + 1)",
                userID: "sample",
                title: row.0,
                description: row.3,
                type: row.1,
                condition: row.2,
                status: .available,
                photos: ["sample:item-\(index + 1)"],
                createdAt: now.addingTimeInterval(Double(-index) * 3600),
                updatedAt: now
            )
        }
    }()
}
