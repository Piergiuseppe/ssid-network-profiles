import Foundation

struct ProfileStore {
    private let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WiFiProfili/profiles.json")

    func load() -> StoreData {
        guard let raw = try? Data(contentsOf: fileURL),
              let data = try? JSONDecoder().decode(StoreData.self, from: raw) else { return StoreData() }
        return data
    }

    func save(_ data: StoreData) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let raw = try? encoder.encode(data) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? raw.write(to: fileURL, options: .atomic)
    }
}
