import SwiftUI

struct BrowseView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var filter: ListingType?
    @State private var sort: SortOrder = .newest
    @State private var showingEditor = false
    @State private var showingAuth = false

    enum SortOrder: String, CaseIterable, Identifiable {
        case newest = "Newest first"
        case oldest = "Oldest first"
        case title = "Title A–Z"

        var id: Self { self }
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    /// Search and type filters run on the device, like the web frontend.
    private var results: [Listing] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        var items = model.listings.filter { item in
            (filter == nil || item.type == filter)
                && (needle.isEmpty || "\(item.title) \(item.description)".lowercased().contains(needle))
        }
        switch sort {
        case .newest: items.sort { $0.createdAt > $1.createdAt }
        case .oldest: items.sort { $0.createdAt < $1.createdAt }
        case .title: items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    filterBar
                    if model.isOffline { offlineBanner }
                    content
                }
                .padding()
            }
            .navigationTitle("Explore")
            .searchable(text: $query, prompt: "Search listings")
            .refreshable { await model.refreshListings() }
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("The campus marketplace", systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Find it. Meet up. Done.")
                .font(.title.bold())
            Text("Buy, trade, and give things away in person.")
                .foregroundStyle(.secondary)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", value: nil)
                ForEach(ListingType.allCases) { type in
                    chip(type == .trade ? "Trades" : type.label, value: type)
                }
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(SortOrder.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                }
            }
        }
    }

    private func chip(_ title: String, value: ListingType?) -> some View {
        let selected = filter == value
        return Button(title) { filter = value }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? Color.primary : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var offlineBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
            VStack(alignment: .leading, spacing: 6) {
                Text("Can't reach the listings API. Showing sample listings.")
                    .font(.subheadline)
                Button("Retry connection") {
                    Task { await model.refreshListings() }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brandYellow.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && !model.hasLoaded {
            ProgressView("Loading listings…")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if results.isEmpty {
            ContentUnavailableView {
                Label("No listings found", systemImage: "magnifyingglass")
            } description: {
                Text("Try another search or browse all listings.")
            } actions: {
                Button("Clear filters") {
                    query = ""
                    filter = nil
                }
            }
        } else {
            Text("\(results.count) \(results.count == 1 ? "listing" : "listings")")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(results) { listing in
                    NavigationLink(value: listing.id) {
                        ListingCard(listing: listing)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        SaveButton(listing: listing)
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                            .padding(6)
                    }
                }
            }
        }
    }
}
