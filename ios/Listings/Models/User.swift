import Foundation

/// A user as returned by `POST /v1/users` and `POST /v1/login`.
/// The password hash never leaves the server.
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}
