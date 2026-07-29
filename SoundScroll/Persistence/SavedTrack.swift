import Foundation
import SwiftData

@Model
final class SavedTrack {
    @Attribute(.unique) var trackID: String
    var title: String
    var artist: String
    var album: String
    var moment: String?
    var isrc: String?
    var previewURL: URL?
    var artworkURL: URL?
    var appleMusicURL: URL?
    var spotifyURL: URL?
    var colors: [UInt]
    var likedAt: Date

    init(track: Track, likedAt: Date = .now) {
        trackID = track.id
        title = track.title
        artist = track.artist
        album = track.album
        moment = track.moment
        isrc = track.isrc
        previewURL = track.previewURL
        artworkURL = track.artworkURL
        appleMusicURL = track.appleMusicURL
        spotifyURL = track.spotifyURL
        colors = track.colors
        self.likedAt = likedAt
    }

    var track: Track {
        Track(
            id: trackID, title: title, artist: artist, album: album, moment: moment, isrc: isrc,
            previewURL: previewURL, artworkURL: artworkURL, appleMusicURL: appleMusicURL,
            spotifyURL: spotifyURL, colors: colors
        )
    }
}
