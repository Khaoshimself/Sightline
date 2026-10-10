import Foundation

enum BackendConfiguration {
    // Keep development credentials in an ignored local resource, outside Git.
    nonisolated private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "BackendConfiguration.local", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return values
    }()
    nonisolated static let baseURL = URL(string: values["BaseURL"] ?? "http://127.0.0.1:3000") ?? URL(string: "http://127.0.0.1:3000")!
    nonisolated static let appToken = values["AppToken"] ?? "PASTE_YOUR_APP_TOKEN"
}
