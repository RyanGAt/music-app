import SwiftUI

struct AppShell: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @AppStorage("previewVolume") private var previewVolume = 0.9

    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Discover", systemImage: "waveform") }

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.white)
        .onAppear { audioPlayer.setVolume(previewVolume) }
        .onChange(of: previewVolume) { _, value in audioPlayer.setVolume(value) }
    }
}
