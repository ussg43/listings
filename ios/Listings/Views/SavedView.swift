import SwiftData
import SwiftUI

struct SavedView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedListing.savedAt, order: .reverse) private var saved: [SavedListing]

    var body: some View {
        NavigationStack {
            Group {
                if saved.isEmpty {
                    ContentUnavailableView(
                        "Nothing saved yet",
                        systemImage: "heart",
                        description: Text("Tap the heart on a listing to keep it here.")
                    )
                } else {
                    List {
                        ForEach(saved) { item in
                            if let listing = model.listing(id: item.listingID) {
                                NavigationLink(value: listing.id) {
                                    ListingRow(listing: listing)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.headline)
                                    Text("No longer available")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: remove)
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: String.self) { ListingDetailView(listingID: $0) }
            .toolbar {
                EditButton().disabled(saved.isEmpty)
            }
        }
    }

    private func remove(at offsets: IndexSet) {
        for index in offsets {
            context.delete(saved[index])
        }
        try? context.save()
    }
}
