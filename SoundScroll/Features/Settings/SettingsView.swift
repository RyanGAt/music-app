import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredGenres") private var storedGenres = DiscoveryPreferences.defaultGenres.joined(separator: ",")
    @AppStorage("allowExplicitContent") private var allowExplicitContent = false
    @AppStorage("autoplayPreviews") private var autoplay = true
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("previewVolume") private var previewVolume = 0.9
    @State private var confirmation: ClearTarget?

    private var selectedGenres: Set<String> {
        get { Set(DiscoveryPreferences.genres(from: storedGenres)) }
        nonmutating set { storedGenres = newValue.sorted().joined(separator: ",") }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Discovery genres") {
                    ForEach(DiscoveryPreferences.availableGenres, id: \.self) { genre in
                        Button { toggleGenre(genre) } label: {
                            HStack {
                                Text(genre).foregroundStyle(.primary)
                                Spacer()
                                if selectedGenres.contains(genre) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                    }
                }

                Section("Playback") {
                    Toggle("Allow explicit content", isOn: $allowExplicitContent)
                    Toggle("Autoplay previews", isOn: $autoplay)
                    Toggle("Haptics", isOn: $haptics)
                    VStack(alignment: .leading) {
                        Text("Preview volume")
                        Slider(value: $previewVolume, in: 0...1)
                    }
                }

                Section("Local data") {
                    Button("Clear Listening History", role: .destructive) { confirmation = .history }
                    Button("Clear Liked Songs", role: .destructive) { confirmation = .likes }
                }

                Section("SoundScroll") {
                    NavigationLink("About") {
                        AboutView()
                    }
                    NavigationLink("Privacy Policy") {
                        PrivacyView()
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                confirmation?.title ?? "Clear local data?",
                isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) { clear(confirmation) }
                Button("Cancel", role: .cancel) { confirmation = nil }
            }
        }
    }

    private func toggleGenre(_ genre: String) {
        var genres = selectedGenres
        if genres.contains(genre) {
            guard genres.count > 1 else { return }
            genres.remove(genre)
        } else {
            genres.insert(genre)
        }
        selectedGenres = genres
    }

    private func clear(_ target: ClearTarget?) {
        do {
            switch target {
            case .history: try modelContext.delete(model: ListeningEvent.self)
            case .likes: try modelContext.delete(model: SavedTrack.self)
            case nil: break
            }
            try modelContext.save()
        } catch { }
        confirmation = nil
    }

    private enum ClearTarget {
        case history, likes
        var title: String {
            switch self {
            case .history: return "Clear all listening history?"
            case .likes: return "Clear all liked songs?"
            }
        }
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill").font(.system(size: 72)).foregroundStyle(.tint)
            Text("SoundScroll").font(.largeTitle.bold())
            Text("Discover a new music moment with every swipe.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("Version 1.0").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding()
        .navigationTitle("About")
    }
}

private struct PrivacyView: View {
    var body: some View {
        List {
            Section("Your data") {
                Text("Likes, listening history, and preferences stay on this device. SoundScroll has no account and does not operate an analytics backend.")
            }
            Section("Music services") {
                Text("Discovery and previews are requested from Apple Music. If you choose a destination or share action, Apple Music or Spotify receives the request under its own privacy policy.")
                Link("Apple Privacy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                Link("Spotify Privacy", destination: URL(string: "https://www.spotify.com/legal/privacy-policy/")!)
            }
        }
        .navigationTitle("Privacy Policy")
    }
}
