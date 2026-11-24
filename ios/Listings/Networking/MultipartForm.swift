import Foundation

/// Builds a `multipart/form-data` body, which the Go API reads with `ParseMultipartForm`.
struct MultipartForm {
    let boundary = "listings-\(UUID().uuidString)"
    private(set) var body = Data()

    mutating func addField(_ name: String, _ value: String) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.appendString("\(value)\r\n")
    }

    mutating func addJPEG(name: String, filename: String, data: Data) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
    }

    func apply(to request: inout URLRequest) {
        var payload = body
        payload.appendString("--\(boundary)--\r\n")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
