import Foundation

struct ProfileStore {
    private let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WiFiProfili/profiles.json")

    func load() -> StoreData {
        (try? read(from: fileURL)) ?? StoreData()
    }

    func save(_ data: StoreData) {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? write(data, to: fileURL)
    }

    func read(from url: URL) throws -> StoreData {
        try JSONDecoder().decode(StoreData.self, from: Data(contentsOf: url))
    }

    func write(_ data: StoreData, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: url, options: .atomic)
    }
}
