import Foundation

/// A single event to be sent to the Lumio backend.
struct TrackEvent: Codable, Sendable {
    let eventName: String
    let timestamp: String
    let propertiesJSON: String

    enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case timestamp
        case propertiesJSON = "properties_json"
    }
}

/// The batch payload sent to POST /v1/track.
struct TrackPayload: Codable, Sendable {
    let appID: String
    let userID: String
    let events: [TrackEvent]

    enum CodingKeys: String, CodingKey {
        case appID = "app_id"
        case userID = "user_id"
        case events
    }
}
