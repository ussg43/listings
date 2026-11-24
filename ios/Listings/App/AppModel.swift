import Foundation
import Observation
import SwiftUI

/// App-wide state: the signed-in user, the server address, and the listings
/// loaded from the Go API. Views read it from the environment.
@MainActor
@Observable
final class AppModel {
    static let defaultServerURL = "http://localhost:8080"

    private(set) var serverURLString: String
    private(set) var currentUser: User?
    private(set) var listings: [Listing] = []
    private(set) var isLoading = false
    private(set) var isOffline = false
    private(set) var hasLoaded = false
    private(set) var toast: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let syncService = ListingSyncService()
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    private enum Keys {
        static let server = "serverURL"
        static let user = "currentUser"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverURLString = defaults.string(forKey: Keys.server) ?? Self.defaultServerURL
        if let data = defaults.data(forKey: Keys.user) {
            currentUser = try? JSONDecoder().decode(User.self, from: data)
        }
    }

    var api: APIClient {
        APIClient(baseURL: URL(string: serverURLString) ?? URL(string: Self.defaultServerURL)!)
    }

    var isSignedIn: Bool { currentUser != nil }

    var myListings: [Listing] {
        guard let id = currentUser?.id else { return [] }
        return listings.filter { $0.userID == id }
    }

    func listing(id: String) -> Listing? {
        listings.first { $0.id == id }
    }

    /// The API has no server-side ownership checks yet, so this is a UI guard only.
    func isOwner(of listing: Listing) -> Bool {
        !listing.isSample && listing.userID == currentUser?.id
    }

    // MARK: Server

    func updateServerURL(_ text: String) throws {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme, ["http", "https"].contains(scheme),
              url.host() != nil else {
            throw APIError(message: "Enter a full address, such as http://localhost:8080")
        }
        serverURLString = trimmed
        defaults.set(trimmed, forKey: Keys.server)
    }

    // MARK: Listings

    /// Loads listings. If the API is unreachable, falls back to sample listings so the
    /// app still demos. Silent refreshes (from the sync service) keep live data on failure.
    func refreshListings(silently: Bool = false) async {
        if !silently { isLoading = true }
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            listings = try await api.fetchListings()
            isOffline = false
        } catch {
            if !silently || !hasLoaded || isOffline {
                isOffline = true
                listings = Listing.samples
            }
        }
    }

    func startAutoRefresh() {
        syncService.start { [weak self] in
            await self?.refreshListings(silently: true)
        }
    }

    func stopAutoRefresh() {
        syncService.stop()
    }

    @discardableResult
    func createListing(_ draft: ListingDraft, photos: [Data]) async throws -> Listing {
        guard let user = currentUser else { throw APIError(message: "Sign in to post a listing.") }
        let listing = try await api.createListing(userID: user.id, draft: draft, photos: photos)
        if isOffline {
            await refreshListings()
        } else {
            listings.insert(listing, at: 0)
        }
        return listing
    }

    @discardableResult
    func updateListing(_ listing: Listing, draft: ListingDraft, newPhotos: [Data], clearPhotos: Bool) async throws -> Listing {
        let updated = try await api.updateListing(id: listing.id, draft: draft, newPhotos: newPhotos, clearPhotos: clearPhotos)
        if let index = listings.firstIndex(where: { $0.id == updated.id }) {
            listings[index] = updated
        }
        return updated
    }

    func deleteListing(_ listing: Listing) async throws {
        try await api.deleteListing(id: listing.id)
        listings.removeAll { $0.id == listing.id }
    }

    // MARK: Accounts

    func signIn(email: String, password: String) async throws {
        setUser(try await api.login(email: email, password: password))
    }

    func register(email: String, password: String) async throws {
        setUser(try await api.register(email: email, password: password))
    }

    func signOut() {
        currentUser = nil
        defaults.removeObject(forKey: Keys.user)
    }

    private func setUser(_ user: User) {
        currentUser = user
        defaults.set(try? JSONEncoder().encode(user), forKey: Keys.user)
    }

    // MARK: Toasts

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }
}
