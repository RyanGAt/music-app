import Foundation

enum DiscoveryPreferences {
    static let availableGenres = ["Pop", "Hip-Hop", "R&B", "Electronic", "Alternative", "Rock", "Jazz", "Classical"]
    static let defaultGenres = ["Pop", "Alternative", "Electronic"]

    static func genres(from storedValue: String) -> [String] {
        let values = storedValue.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        return values.isEmpty ? defaultGenres : values
    }
}
