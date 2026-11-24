import SwiftUI

struct ListingDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let listingID: String

    @State private var showingEditor = false
    @State private var showingMeetup = false
    @State private var confirmingDelete = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let listing = model.listing(id: listingID) {
                content(listing)
            } else {
                ContentUnavailableView(
                    "Listing unavailable",
                    systemImage: "shippingbox",
                    description: Text("This listing may have been removed.")
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ listing: Listing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gallery(listing)

                VStack(alignment: .leading, spacing: 8) {
                    Pill(text: listing.isSample ? "Sample listing" : listing.status.label, prominent: true)
                    Text(listing.title)
                        .font(.title2.bold())
                    Text("\(listing.type.label) · \(listing.condition.label)")
                        .foregroundStyle(.secondary)
                    if !listing.isSample {
                        Text("Posted \(listing.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                actions(listing)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Divider()
                Text("About this item")
                    .font(.headline)
                Text(listing.description.isEmpty ? "No description provided." : listing.description)
            }
            .padding()
        }
        .sheet(isPresented: $showingEditor) { ListingEditorView(existing: listing) }
        .sheet(isPresented: $showingMeetup) { MeetupEditorView(listing: listing) }
        .confirmationDialog("Delete this listing?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete listing", role: .destructive) {
                Task { await delete(listing) }
            }
        } message: {
            Text("This removes the listing and its photos for everyone.")
        }
    }

    private func gallery(_ listing: Listing) -> some View {
        let photos: [String?] = listing.photos.isEmpty ? [nil] : listing.photos.map { Optional($0) }
        return TabView {
            ForEach(Array(photos.enumerated()), id: \.offset) { _, path in
                Color.clear
                    .overlay { ListingPhoto(path: path) }
                    .clipped()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func actions(_ listing: Listing) -> some View {
        HStack(spacing: 12) {
            if model.isOwner(of: listing) {
                Button("Edit listing") { showingEditor = true }
                    .buttonStyle(.borderedProminent)
                Button("Delete", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(.bordered)
                    .disabled(isDeleting)
            } else if listing.status == .available {
                Button {
                    showingMeetup = true
                } label: {
                    Label("Plan a meetup", systemImage: "calendar")
                }
                .buttonStyle(.borderedProminent)
            }
            SaveButton(listing: listing, showsLabel: true)
                .buttonStyle(.bordered)
        }
    }

    private func delete(_ listing: Listing) async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await model.deleteListing(listing)
            model.showToast("Listing deleted")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
