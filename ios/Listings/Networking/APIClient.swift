import Foundation

struct APIError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

/// Talks to the Go listings API (backend/README.md).
/// Successful responses are wrapped as `{"data": ...}` and errors as `{"error": "..."}`.
struct APIClient: Sendable {
    let baseURL: URL
    var session: URLSession = .shared

    // MARK: Accounts

    func register(email: String, password: String) async throws -> User {
        try await postJSON(path: "v1/users", body: Credentials(email: email, password: password))
    }

    func login(email: String, password: String) async throws -> User {
        try await postJSON(path: "v1/login", body: Credentials(email: email, password: password))
    }

    // MARK: Listings

    func fetchListings(userID: String? = nil) async throws -> [Listing] {
        let query = userID.map { [URLQueryItem(name: "user_id", value: $0)] } ?? []
        var request = URLRequest(url: url("v1/listings", query: query))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return try await decode(request)
    }

    func fetchListing(id: String) async throws -> Listing {
        try await decode(URLRequest(url: url("v1/listings/\(id)")))
    }

    func createListing(userID: String, draft: ListingDraft, photos: [Data]) async throws -> Listing {
        var form = MultipartForm()
        form.addField("user_id", userID)
        addFields(of: draft, to: &form)
        addPhotos(photos, to: &form)

        var request = URLRequest(url: url("v1/listings"))
        request.httpMethod = "POST"
        form.apply(to: &request)
        return try await decode(request)
    }

    /// New photos replace the current ones. With no new photos,
    /// `clearPhotos` removes the current photos; otherwise they're kept.
    func updateListing(id: String, draft: ListingDraft, newPhotos: [Data], clearPhotos: Bool) async throws -> Listing {
        var form = MultipartForm()
        addFields(of: draft, to: &form)
        addPhotos(newPhotos, to: &form)
        if newPhotos.isEmpty && clearPhotos {
            form.addField("clear_photos", "true")
        }

        var request = URLRequest(url: url("v1/listings/\(id)"))
        request.httpMethod = "PUT"
        form.apply(to: &request)
        return try await decode(request)
    }

    func deleteListing(id: String) async throws {
        var request = URLRequest(url: url("v1/listings/\(id)"))
        request.httpMethod = "DELETE"
        try await perform(request)
    }

    func isHealthy() async -> Bool {
        var request = URLRequest(url: url("health"))
        request.timeoutInterval = 5
        return (try? await perform(request)) != nil
    }

    /// Resolves a photo string from the API (absolute URL or `/v1/photos/...` path),
    /// or a bundled sample photo (`sample:item-1`).
    func photoURL(for path: String) -> URL? {
        if path.hasPrefix("sample:") {
            return Bundle.main.url(forResource: String(path.dropFirst("sample:".count)), withExtension: "jpg")
        }
        if let absolute = URL(string: path), absolute.scheme != nil {
            return absolute
        }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    // MARK: Plumbing

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }

    private struct DataEnvelope<Value: Decodable>: Decodable {
        let data: Value
    }

    private struct ErrorEnvelope: Decodable {
        let error: String
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = APIDate.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(text)")
            }
            return date
        }
        return decoder
    }()

    private func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var result = baseURL.appending(path: path)
        if !query.isEmpty {
            result.append(queryItems: query)
        }
        return result
    }

    private func addFields(of draft: ListingDraft, to form: inout MultipartForm) {
        form.addField("title", draft.trimmedTitle)
        form.addField("description", draft.description)
        form.addField("type", draft.type.rawValue)
        form.addField("condition", draft.condition.rawValue)
        form.addField("status", draft.status.rawValue)
    }

    private func addPhotos(_ photos: [Data], to form: inout MultipartForm) {
        for (index, photo) in photos.prefix(5).enumerated() {
            form.addJPEG(name: "photos", filename: "photo-\(index + 1).jpg", data: photo)
        }
    }

    private func postJSON<Body: Encodable, Value: Decodable>(path: String, body: Body) async throws -> Value {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await decode(request)
    }

    private func decode<Value: Decodable>(_ request: URLRequest) async throws -> Value {
        let data = try await perform(request)
        do {
            return try Self.decoder.decode(DataEnvelope<Value>.self, from: data).data
        } catch {
            throw APIError(message: "The listings API sent a response the app couldn't read.")
        }
    }

    @discardableResult
    private func perform(_ request: URLRequest) async throws -> Data {
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw APIError(message: "Couldn't reach the listings API at \(baseURL.absoluteString). Make sure the Go server is running.")
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Unexpected response from the listings API.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error
            throw APIError(message: message ?? "The listings API returned HTTP \(http.statusCode).")
        }
        return data
    }
}

/// Go encodes `time.Time` as RFC 3339 with up to 9 fractional digits
/// (e.g. `2026-11-23T19:30:00.123456789Z`). Trim to milliseconds before parsing.
enum APIDate {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let whole: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ text: String) -> Date? {
        var value = text
        if let dot = value.firstIndex(of: ".") {
            let digitsStart = value.index(after: dot)
            let digitsEnd = value[digitsStart...].firstIndex(where: { !$0.isNumber }) ?? value.endIndex
            let millis = String(value[digitsStart..<digitsEnd].prefix(3))
                .padding(toLength: 3, withPad: "0", startingAt: 0)
            value = String(value[..<digitsStart]) + millis + String(value[digitsEnd...])
        }
        return fractional.date(from: value) ?? whole.date(from: value)
    }
}
