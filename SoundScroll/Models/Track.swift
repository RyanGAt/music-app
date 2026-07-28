import SwiftUI

struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let moment: String
    let detail: String
    let audioResource: String
    let startTime: TimeInterval
    let colors: [Color]

    static let samples: [Track] = [
        Track(
            id: "lofi-drift",
            title: "Lofi Drift",
            artist: "Signal Shore",
            moment: "A soft place to land.",
            detail: "MIDNIGHT NOTES  ·  0:42",
            audioResource: "welcome-to-paradise",
            startTime: 42,
            colors: [Color(hex: 0x242A58), Color(hex: 0x895B74), Color(hex: 0xE39A76)]
        ),
        Track(
            id: "night-drive",
            title: "Night Drive",
            artist: "Neon District",
            moment: "Windows down. City awake.",
            detail: "AFTER HOURS  ·  1:08",
            audioResource: "she-said",
            startTime: 68,
            colors: [Color(hex: 0x071B35), Color(hex: 0x284E74), Color(hex: 0xD34D8C)]
        ),
        Track(
            id: "golden-hour",
            title: "Golden Hour Loop",
            artist: "Ember Lines",
            moment: "Keep this feeling a little longer.",
            detail: "SUNSET TAPES  ·  0:24",
            audioResource: "the-receipt",
            startTime: 24,
            colors: [Color(hex: 0x432136), Color(hex: 0xB65345), Color(hex: 0xF3B75B)]
        ),
        Track(
            id: "slow-bloom",
            title: "Slow Bloom",
            artist: "Quiet Hours",
            moment: "Some songs arrive right on time.",
            detail: "ROOM TO BREATHE  ·  0:16",
            audioResource: "placeholder-1",
            startTime: 16,
            colors: [Color(hex: 0x163C38), Color(hex: 0x437967), Color(hex: 0xD9A66C)]
        )
    ]
}

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
