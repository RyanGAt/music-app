import Foundation
import SwiftUI

/// A UI-friendly track returned by a music catalogue.
///
/// Preview and destination URLs are deliberately separate: SoundScroll streams the
/// provider's public preview while the destination opens the full song in its app.
struct Track: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let moment: String?
    let isrc: String?
    let previewURL: URL?
    let artworkURL: URL?
    let appleMusicURL: URL?
    let spotifyURL: URL?
    let colors: [UInt]

    var gradientColors: [Color] { colors.map(Color.init(hex:)) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
}

#if DEBUG
extension Track {
    /// Used only when catalogue loading is unavailable in development builds.
    static let developmentFallback: [Track] = [
        Track(
            id: "dev-lofi-drift",
            title: "Lofi Drift",
            artist: "Signal Shore",
            album: "Midnight Notes",
            moment: "A soft place to land.",
            isrc: nil,
            previewURL: Bundle.main.url(forResource: "welcome-to-paradise", withExtension: "mp3"),
            artworkURL: nil,
            appleMusicURL: nil,
            spotifyURL: nil,
            colors: [0x242A58, 0x895B74, 0xE39A76]
        ),
        Track(
            id: "dev-night-drive",
            title: "Night Drive",
            artist: "Neon District",
            album: "After Hours",
            moment: "Windows down. City awake.",
            isrc: nil,
            previewURL: Bundle.main.url(forResource: "she-said", withExtension: "mp3"),
            artworkURL: nil,
            appleMusicURL: nil,
            spotifyURL: nil,
            colors: [0x071B35, 0x284E74, 0xD34D8C]
        )
    ]
}
#endif

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
