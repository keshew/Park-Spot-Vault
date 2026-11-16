import Foundation

enum ArrivalDirectory {
    static let entry = URL(string: "https://parkspot.cyou/app.php")!
    static let pageAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static func address(_ raw: String?) -> URL? {
        guard let raw,
              let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

struct ArrivalSignals: Sendable {
    let attributionJSON: String?
    let registrationToken: String
    let attributionID: String
    let advertisingID: String
    let hardware: String
    let notice: NoticeArrival?

    func parameters(clientID: String) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "firebase_push_token", value: registrationToken),
            URLQueryItem(name: "adjust_id", value: attributionID),
            URLQueryItem(name: "idfa", value: advertisingID),
            URLQueryItem(name: "device_model", value: hardware),
            URLQueryItem(name: "isfrompush", value: notice == nil ? "0" : "1"),
            URLQueryItem(name: "client_id", value: clientID)
        ]
        if let identifier = notice?.identifier {
            items.append(URLQueryItem(name: "push_id", value: identifier))
        }
        return items
    }

    func encode() throws -> Data {
        var campaign: [String: Any] = [:]
        if let attributionJSON,
           let values = try? JSONSerialization.jsonObject(with: Data(attributionJSON.utf8)) as? [String: Any] {
            let fields = ["trackerToken", "trackerName", "network", "campaign", "adgroup",
                          "creative", "clickLabel", "costType", "costCurrency"]
            for field in fields {
                campaign[field] = values[field] as? String ?? ""
            }
            campaign["costAmount"] = values["costAmount"] as? Double ?? 0
            campaign["jsonResponse"] = attributionJSON
        }
        return try JSONSerialization.data(withJSONObject: [
            "adjust": campaign,
            "referrer": "utm_source=appstore&utm_medium=organic"
        ])
    }
}

private struct ArrivalReply: Decodable {
    let session: String?
    let response: String?

    enum CodingKeys: String, CodingKey {
        case session = "session_id"
        case response
    }

    var destination: URL? {
        guard let url = ArrivalDirectory.address(response) else { return nil }
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let session = session?.trimmingCharacters(in: .whitespacesAndNewlines),
              !session.isEmpty else { return url }

        var parameters = parts.queryItems ?? []
        guard !parameters.contains(where: { $0.name == "session_id" && !($0.value ?? "").isEmpty }) else {
            return url
        }
        parameters.removeAll { $0.name == "session_id" }
        parameters.append(URLQueryItem(name: "session_id", value: session))
        parts.queryItems = parameters
        return parts.url
    }
}

actor ParkingPageClient {
    private enum ResponseError: Error {
        case missingServiceLink
        case invalidRequestURL
        case invalidResponse
        case rejected(Int)
    }

    private let defaults: UserDefaults
    private let session: URLSession

    init(storageSuite: String? = nil, session: URLSession = .shared) {
        defaults = storageSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.session = session
    }

    func lookup(_ signals: ArrivalSignals) async throws -> URL? {
        let entry = try await serviceURL()
        let parameters = signals.parameters(clientID: ArrivalLedger.clientIdentifier(in: defaults))
        let body = try signals.encode()
        let request = try makePageRequest(at: entry, parameters: parameters, body: body)
        let (data, _) = try await response(to: request)
        return try JSONDecoder().decode(ArrivalReply.self, from: data).destination
    }

    private func serviceURL() async throws -> URL {
        if let address = ArrivalLedger.savedDirectory(in: defaults) { return address }
        let discovery = request(at: ArrivalDirectory.entry, method: "GET")
        let (_, reply) = try await response(to: discovery)
        guard let address = ArrivalDirectory.address(reply.value(forHTTPHeaderField: "service-link")) else {
            throw ResponseError.missingServiceLink
        }
        ArrivalLedger.saveDirectory(address, in: defaults)
        return address
    }

    private func makePageRequest(at entry: URL, parameters: [URLQueryItem], body: Data) throws -> URLRequest {
        let reserved = Set(parameters.map(\.name)).union(["push_id"])
        guard var components = URLComponents(url: entry, resolvingAgainstBaseURL: false) else {
            throw ResponseError.invalidRequestURL
        }
        components.queryItems = (components.queryItems ?? []).filter { !reserved.contains($0.name) } + parameters
        guard let url = components.url else { throw ResponseError.invalidRequestURL }

        var request = request(at: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private func request(at address: URL, method: String) -> URLRequest {
        var request = URLRequest(url: address)
        request.httpMethod = method
        request.setValue(ArrivalLedger.installationIdentifier(in: defaults), forHTTPHeaderField: "client-uuid")
        request.setValue(ArrivalDirectory.pageAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func response(to request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ResponseError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return (data, http)
        default: throw ResponseError.rejected(http.statusCode)
        }
    }
}
