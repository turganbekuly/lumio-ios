import Foundation

#if os(iOS)
import UIKit
#endif

#if canImport(AdServices)
import AdServices
#endif

/// Lumio iOS SDK — Revenue-First Analytics for iOS.
///
/// Usage:
/// ```swift
/// Lumio.shared.configure(appKey: "lm_your_key")
/// Lumio.shared.trackStep(name: "welcome", order: 1)
/// Lumio.shared.trackPaywallView(name: "main_paywall")
/// Lumio.shared.trackCoreAction(name: "expense_logged")
/// Lumio.shared.identifyUser(property: "source", value: "tiktok")
/// ```
public final class Lumio: Sendable {
    public static let shared = Lumio()

    private let _queue = Mutex<EventQueue?>(nil)
    private let _config = Mutex<Configuration?>(nil)
    private let deviceID: any DeviceIdentifying

    private init(deviceID: any DeviceIdentifying = DeviceIdentifier()) {
        self.deviceID = deviceID
    }

    /// Initialize the SDK with your app key.
    /// Call this once in your app's launch (e.g., `App.init()` or `application(_:didFinishLaunchingWithOptions:)`).
    ///
    /// Automatically collects:
    /// - **platform**: iPhone or iPad
    /// - **ios_version**: e.g. "17.4"
    /// - **source**: "apple_search_ads" or "organic" (resolved server-side via Apple's AdServices)
    public func configure(appKey: String, endpoint: URL? = nil) {
        let config = Configuration(
            appKey: appKey,
            endpoint: endpoint ?? URL(string: "https://api.lumio.io")!
        )
        _config.withLock { $0 = config }

        let userID = deviceID.identifier()
        let networkClient = NetworkClient()
        let persistentStore = PersistentStore()
        let queue = EventQueue(
            config: config,
            userID: userID,
            networkClient: networkClient,
            persistentStore: persistentStore
        )

        _queue.withLock { $0 = queue }

        // Retry any persisted batches from previous sessions
        Task {
            await queue.retryPersisted()
        }

        // Auto-collect device and attribution properties
        autoCollectProperties()
    }

    /// Track a step in the user's onboarding/activation funnel.
    ///
    /// - Parameters:
    ///   - name: The step identifier (e.g., "age_selection", "goal_setting").
    ///   - order: The sequential order of this step (1, 2, 3...).
    public func trackStep(name: String, order: Int) {
        let props = encode(["step_name": name, "step_order": order] as [String: Any])
        enqueue(eventName: "step", properties: props)
    }

    /// Tag the current user with a property for cohort analysis.
    ///
    /// - Parameters:
    ///   - property: The property key (e.g., "source", "goal").
    ///   - value: The property value (e.g., "tiktok", "debt_tracking").
    public func identifyUser(property: String, value: String) {
        let props = encode(["user_property": property, "user_value": value])
        enqueue(eventName: "identify", properties: props)
    }

    /// Track when a paywall is displayed to the user.
    ///
    /// - Parameter name: The paywall identifier (e.g., "main_paywall").
    public func trackPaywallView(name: String) {
        let props = encode(["paywall_name": name])
        enqueue(eventName: "paywall_view", properties: props)
    }

    /// Track the core "Aha!" action that defines user activation.
    /// Only fires once per action name per device — subsequent calls are no-ops.
    ///
    /// - Parameter name: The action identifier (e.g., "expense_logged", "focus_session_completed").
    public func trackCoreAction(name: String) {
        let key = "com.lumio.core_action_tracked.\(name)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let props = encode(["core_action": name])
        enqueue(eventName: "core_action", properties: props)
    }

    /// Force-flush all queued events. Call this in `applicationWillTerminate` or `sceneDidDisconnect`.
    public func flush() {
        guard let queue = _queue.withLock({ $0 }) else { return }
        Task {
            await queue.flush()
        }
    }

    // MARK: - Auto-Collection

    private func autoCollectProperties() {
        #if os(iOS)
        let platform: String
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: platform = "iPhone"
        case .pad: platform = "iPad"
        default: platform = "other"
        }
        identifyUser(property: "platform", value: platform)
        identifyUser(property: "ios_version", value: UIDevice.current.systemVersion)
        #endif

        detectSource()
    }

    private func detectSource() {
        #if canImport(AdServices)
        if #available(iOS 14.3, macOS 11.1, *) {
            do {
                let token = try AAAttribution.attributionToken()
                // Send raw token to backend — the server calls Apple's AdServices API
                // to resolve whether this is an ASA install or organic, then stores
                // the resolved "source" user property.
                identifyUser(property: "_asa_token", value: token)
                return
            } catch {
                // Token unavailable — not an ASA install
            }
        }
        #endif
        identifyUser(property: "source", value: "organic")
    }

    // MARK: - Private

    private func enqueue(eventName: String, properties: String) {
        guard let queue = _queue.withLock({ $0 }) else {
            #if DEBUG
            print("[Lumio] SDK not configured. Call configure(appKey:) first.")
            #endif
            return
        }

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let event = TrackEvent(
            eventName: eventName,
            timestamp: iso8601.string(from: Date()),
            propertiesJSON: properties
        )

        Task {
            await queue.enqueue(event)
        }
    }

    private func encode(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private func encode(_ dict: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

#if canImport(SwiftUI)
import SwiftUI

public extension Lumio {
    /// A drop-in SwiftUI view for self-reported source attribution.
    /// Present during onboarding to ask users how they found your app.
    typealias SourcePickerView = GMSourcePickerView
}
#endif

/// Simple mutex for thread-safe access in nonisolated Sendable context.
private final class Mutex<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
