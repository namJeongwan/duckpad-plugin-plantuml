import Foundation

@MainActor final class PlantUMLStrings {
    private let bundle: Bundle
    var language: String
    init(directory: URL, language: String) {
        bundle = Bundle(url: directory) ?? .main; self.language = language
    }
    func text(_ key: String) -> String {
        let fallback = NSLocalizedString(key, tableName: "locale-en", bundle: bundle, value: key, comment: "")
        return NSLocalizedString(key, tableName: "locale-" + language, bundle: bundle, value: fallback, comment: "")
    }
}
