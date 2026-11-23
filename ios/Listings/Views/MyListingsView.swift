import SwiftUI

struct MyListingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showingEditor = false
    @State private var showingAuth = false
    @State private var pendingDelete: Listing?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if !model.isSignedIn {
                    ContentUnavailableView {
                        Label("Sign in to sell", systemImage: "tag")
                    } description: {
                        Text("Post things you want to sell, trade, or give away.")
                    } actions: {
                        Button("Sign in") { showingAuth = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if model.myListings.isEmpty {
                    ContentUnavailableView {
                        Label("No listings yet", systemImage: "shippingbox")
                    } description: {
                        Text("Items you post will show up here.")
                    } actions: {
                        Button("Post a listing") { showingEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(model.myListings) { listing in
                            NavigationLink(value: listing.id) {
                                ListingRow(listing: listing)
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { pendingDelete = listing }
                            }
                        }
                    }
                    .refreshable { await model.refreshListings() }
                }
            }
            .navigationTitle("My listings")
            .navigationDestination(for: String.self) { ListingDetailView(listingID: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if model.isSignedIn { showingEditor = true } else { showingAuth = true }
                    } label: {
                        Label("Post listing", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) { ListingEditorView(existing: nil) }
            .sheet(isPresented: $showingAuth) { AuthView() }
            .confirmationDialog(
                "Delete this listing?",
                isPresented: $pendingDelete.isPresent(),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { listing in
                Button("Delete \u{201C}\(listing.title)\u{201D}", role: .destructive) {
                    Task { await delete(listing) }
                }
            }
            .alert("Couldn't delete the listing", isPresented: $errorMessage.isPresent()) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func delete(_ listing: Listing) async {
        do {
            try await model.deleteListing(listing)
            model.showToast("Listing deleted")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
