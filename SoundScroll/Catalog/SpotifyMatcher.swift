import Foundation

enum SpotifyMatchState: Equatable {
    case idle, matching, exact(URL), unavailable, failed
}

/// Matches Spotify tracks only when the app is supplied a short-lived Web API token.
/// Tokens must be issued by a server; a Spotify client secret is never embedded in the app.
actor SpotifyMatcher {
    static let shared = SpotifyMatcher()

    func match(_ track: Track) async -> SpotifyMatchState {
        if let cached = SpotifyMatchCache.shared.url(for: track.id) { return .exact(cached) }
        guard let token = Bundle.main.object(forInfoDictionaryKey: "SpotifyAccessToken") as? String,
              !token.isEmpty, !token.hasPrefix("$(") else { return .unavailable }

        do {
            if let isrc = track.isrc,
               let url = try await search(query: "isrc:\(isrc)", token: token, track: track, strict: false) {
                SpotifyMatchCache.shared.store(url, for: track.id)
                return .exact(url)
            }
            let query = "track:\(track.title) artist:\(track.artist)"
            if let url = try await search(query: query, token: token, track: track, strict: true) {
                SpotifyMatchCache.shared.store(url, for: track.id)
                return .exact(url)
            }
            return .failed
        } catch {
            return .failed
        }
    }

    private func search(query: String, token: String, track: Track, strict: Bool) async throws -> URL? {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: "track"), URLQueryItem(name: "limit", value: "5")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw MatchError.requestFailed }
        let payload = try JSONDecoder().decode(SearchResponse.self, from: data)
        let candidate = payload.tracks.items.first { item in
            !strict || (item.name.normalized == track.title.normalized && item.artists.contains { $0.name.normalized == track.artist.normalized })
        }
        return candidate.flatMap { URL(string: $0.externalURLs.spotify) }
    }

    private struct SearchResponse: Decodable { let tracks: Tracks }
    private struct Tracks: Decodable { let items: [Item] }
    private struct Item: Decodable {
        let name: String; let artists: [Artist]; let externalURLs: ExternalURLs
        enum CodingKeys: String, CodingKey { case name, artists; case externalURLs = "external_urls" }
    }
    private struct Artist: Decodable { let name: String }
    private struct ExternalURLs: Decodable { let spotify: String }
    private enum MatchError: Error { case requestFailed }
}

final class SpotifyMatchCache: @unchecked Sendable {
    static let shared = SpotifyMatchCache()
    private let defaults = UserDefaults.standard
    private let prefix = "spotify-match."
    func url(for trackID: String) -> URL? { defaults.string(forKey: prefix + trackID).flatMap(URL.init(string:)) }
    func store(_ url: URL, for trackID: String) { defaults.set(url.absoluteString, forKey: prefix + trackID) }
}

private extension String {
    var normalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
