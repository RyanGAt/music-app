import SwiftUI

@main
struct SoundScrollApp: App {
    @StateObject private var audioPlayer = AudioPlayer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            FeedView(tracks: Track.samples)
                .environmentObject(audioPlayer)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        audioPlayer.pause()
                    }
                }
        }
    }
}
