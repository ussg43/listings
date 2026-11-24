import SwiftData
import SwiftUI

extension Color {
    /// The yellow from the web frontend's hero art.
    static let brandYellow = Color(red: 1.0, green: 0.906, blue: 0.443)
}

/// Shows a listing photo from the API (or a bundled sample), with a box placeholder.
/// Fills whatever frame its parent gives it, so wrap it in a sized container.
struct ListingPhoto: View {
    @Environment(AppModel.self) private var model
    let path: String?

    var body: some View {
        ZStack {
            Color.brandYellow.opacity(0.35)
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            if let path, let url = model.api.photoURL(for: path) {
                if url.isFileURL {
                    if let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                } else {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    }
                }
            }
        }
    }
}

/// A square photo tile with rounded corners.
struct PhotoTile: View {
    let path: String?
    var cornerRadius: CGFloat = 12

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { ListingPhoto(path: path) }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct Pill: View {
    let text: String
    var prominent = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(prominent ? Color.brandYellow : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(prominent ? Color.black : Color.primary)
    }
}

struct ListingCard: View {
    let listing: Listing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhotoTile(path: listing.photos.first, cornerRadius: 14)
                .overlay(alignment: .topLeading) {
                    Pill(text: listing.badgeText, prominent: true).padding(8)
                }
            Text(listing.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(listing.condition.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct ListingRow: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            PhotoTile(path: listing.photos.first, cornerRadius: 10)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title).font(.headline).lineLimit(1)
                Text("\(listing.type.label) · \(listing.condition.label) · \(listing.status.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Heart toggle backed by the on-device SwiftData store.
struct SaveButton: View {
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var model
    @Query private var matches: [SavedListing]
    let listing: Listing
    let showsLabel: Bool

    init(listing: Listing, showsLabel: Bool = false) {
        self.listing = listing
        self.showsLabel = showsLabel
        let id = listing.id
        _matches = Query(filter: #Predicate<SavedListing> { $0.listingID == id })
    }

    private var isSaved: Bool { !matches.isEmpty }

    var body: some View {
        Button(action: toggle) {
            if showsLabel {
                Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "heart.fill" : "heart")
            } else {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .foregroundStyle(isSaved ? Color.red : Color.primary)
            }
        }
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save listing")
    }

    private func toggle() {
        let wasSaved = isSaved
        if wasSaved {
            for item in matches { context.delete(item) }
        } else {
            context.insert(SavedListing(listingID: listing.id, title: listing.title))
        }
        try? context.save()
        model.showToast(wasSaved ? "Removed from saved" : "Listing saved")
    }
}

extension Binding {
    /// Turns an optional binding into a Bool for `.alert` / `.confirmationDialog`.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { if !$0 { self.wrappedValue = nil } }
        )
    }
}
