import SwiftUI
import SwiftData

@main
struct SoundScrollApp: App {
    @StateObject private var audioPlayer = AudioPlayer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(audioPlayer)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        audioPlayer.pause()
                    }
                }
        }
        .modelContainer(for: [SavedTrack.self, ListeningEvent.self])
    }
}
