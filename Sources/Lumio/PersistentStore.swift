import Foundation

/// Persists failed event batches to disk for retry on next launch.
actor PersistentStore {
    private let directory: URL

    init(directory: URL? = nil) {
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = appSupport.appendingPathComponent("Lumio/pending")
        }
        self.directory = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Save a failed batch to disk.
    func save(payload: TrackPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let filename = UUID().uuidString + ".json"
        let fileURL = directory.appendingPathComponent(filename)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Load all pending batches from disk.
    func loadAll() -> [TrackPayload] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }

        var payloads: [TrackPayload] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let payload = try? JSONDecoder().decode(TrackPayload.self, from: data) else {
                // Remove corrupt files
                try? FileManager.default.removeItem(at: file)
                continue
            }
            payloads.append(payload)
        }
        return payloads
    }

    /// Remove a specific pending file after successful send.
    func removeAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.pathExtension == "json" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
