import Foundation
import SwiftData

enum SharedStoreError: Error {
    case missingAppGroupContainer(groupID: String)
}

enum SharedStore {
    static let groupID = "group.com.a81808.naniyaru"
    static let storeFileName = "NaniYaru.store"
    private static let resetVersion = 2
    private static let resetKey = "storeResetVersion"

    static func storeURL(in baseURL: URL) -> URL {
        baseURL.appendingPathComponent(storeFileName, isDirectory: false)
    }

    static func makeContainer(
        fileManager: FileManager = .default,
        performResetIfNeeded: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema([TaskSection.self, TaskItem.self])
        guard let baseURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw SharedStoreError.missingAppGroupContainer(groupID: groupID)
        }

        if performResetIfNeeded {
            resetStoreIfNeeded(baseURL: baseURL, fileManager: fileManager)
        }

        let config = ModelConfiguration(schema: schema, url: storeURL(in: baseURL))
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static func resetStoreIfNeeded(baseURL: URL, fileManager: FileManager) {
        guard let defaults = UserDefaults(suiteName: groupID) else {
            return
        }

        let currentVersion = defaults.integer(forKey: resetKey)
        guard currentVersion < resetVersion else {
            return
        }

        do {
            let files = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
            for file in files where file.lastPathComponent.hasPrefix(storeFileName) {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            // Reset best-effort only; container creation will surface hard failures.
        }

        defaults.set(resetVersion, forKey: resetKey)
    }
}
