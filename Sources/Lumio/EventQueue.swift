import Foundation

/// Actor-isolated event queue that batches events and flushes them periodically.
actor EventQueue {
    private var events: [TrackEvent] = []
    private var flushTask: Task<Void, Never>?

    private let config: Configuration
    private let userID: String
    private let networkClient: any NetworkClientProtocol
    private let persistentStore: PersistentStore

    init(
        config: Configuration,
        userID: String,
        networkClient: any NetworkClientProtocol,
        persistentStore: PersistentStore
    ) {
        self.config = config
        self.userID = userID
        self.networkClient = networkClient
        self.persistentStore = persistentStore
    }

    /// Enqueue an event and flush if threshold is reached.
    func enqueue(_ event: TrackEvent) {
        events.append(event)

        if events.count >= config.flushThreshold {
            scheduleFlush(immediate: true)
        } else if flushTask == nil {
            scheduleFlush(immediate: false)
        }
    }

    /// Flush all queued events immediately.
    func flush() async {
        await performFlush()
    }

    /// Retry any persisted batches from previous sessions.
    func retryPersisted() async {
        let pending = await persistentStore.loadAll()
        guard !pending.isEmpty else { return }

        var allSucceeded = true
        for payload in pending {
            let success = await networkClient.send(payload: payload, config: config)
            if !success {
                allSucceeded = false
            }
        }

        if allSucceeded {
            await persistentStore.removeAll()
        }
    }

    private func scheduleFlush(immediate: Bool) {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(nanoseconds: UInt64((self?.config.flushInterval ?? 30) * 1_000_000_000))
            }
            await self?.performFlush()
        }
    }

    private func performFlush() async {
        guard !events.isEmpty else {
            flushTask = nil
            return
        }

        let batch = events
        events.removeAll()
        flushTask = nil

        let payload = TrackPayload(
            appID: config.appKey,
            userID: userID,
            events: batch
        )

        let success = await networkClient.send(payload: payload, config: config)
        if !success {
            await persistentStore.save(payload: payload)
        }
    }
}
