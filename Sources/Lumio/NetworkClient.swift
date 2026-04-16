import Foundation

/// Protocol for sending event batches to the backend.
protocol NetworkClientProtocol: Sendable {
    func send(payload: TrackPayload, config: Configuration) async -> Bool
}

/// URLSession-based network client with exponential backoff retry.
struct NetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(payload: TrackPayload, config: Configuration) async -> Bool {
        let url = config.endpoint.appendingPathComponent("v1/track")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.appKey, forHTTPHeaderField: "X-App-Key")
        request.timeoutInterval = 30

        guard let body = try? JSONEncoder().encode(payload) else {
            return false
        }
        request.httpBody = body

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   (200..<300).contains(httpResponse.statusCode) {
                    // Parse response to check accepted count
                    if let result = try? JSONDecoder().decode(TrackResponse.self, from: data) {
                        return result.accepted > 0
                    }
                    return true
                }
            } catch {
                // Network error — retry with backoff
            }

            if attempt < maxRetries - 1 {
                let delay = baseDelay * pow(4.0, Double(attempt)) // 1s, 4s, 16s
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        return false
    }
}

private struct TrackResponse: Decodable {
    let accepted: Int
}
