import SwiftUI

struct TrackPage: View {
    let track: Track

    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var dragProgress: Double?

    private var isCurrent: Bool { audioPlayer.currentTrackID == track.id }
    private var displayedProgress: Double {
        if let dragProgress { return dragProgress }
        guard isCurrent, audioPlayer.duration > 0 else { return 0 }
        return audioPlayer.elapsed / audioPlayer.duration
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: track.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    RadialGradient(
                        colors: [.white.opacity(0.16), .clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: 360
                    )
                }
                .overlay(Color.black.opacity(0.18))
                .ignoresSafeArea()

            Circle()
                .fill(track.colors.last?.opacity(0.38) ?? .clear)
                .frame(width: 420, height: 420)
                .blur(radius: 65)
                .offset(x: -150, y: 250)

            VStack(spacing: 0) {
                header
                    .padding(.top, 12)

                Spacer()

                artwork

                Spacer(minLength: 36)

                metadata

                controls
                    .padding(.top, 24)
                    .padding(.bottom, 38)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                Text("SOUNDSCROLL")
                    .tracking(2.2)
            }
            .font(.caption.weight(.bold))

            Spacer()

            Button {
                audioPlayer.isMuted.toggle()
            } label: {
                Image(systemName: audioPlayer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.isMuted ? "Unmute" : "Mute")
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.34), radius: 35, y: 22)

            VStack(spacing: 20) {
                Image(systemName: "waveform")
                    .font(.system(size: 80, weight: .ultraLight))
                    .symbolEffect(.variableColor.iterative, isActive: isCurrent && audioPlayer.isPlaying)
                Text("“\(track.moment)”")
                    .font(.system(size: 23, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .foregroundStyle(.white)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 360)
    }

    private var metadata: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(track.detail)
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.58))
                Text(track.title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityHidden(true)
        }
    }

    private var controls: some View {
        VStack(spacing: 18) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22)).frame(height: 4)
                    Capsule().fill(.white).frame(width: width * displayedProgress, height: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragProgress = max(0, min(1, value.location.x / width))
                        }
                        .onEnded { value in
                            let progress = max(0, min(1, value.location.x / width))
                            if !isCurrent { audioPlayer.play(track, crossfade: false) }
                            audioPlayer.seek(to: progress)
                            dragProgress = nil
                        }
                )
            }
            .frame(height: 20)
            .accessibilityLabel("Playback progress")
            .accessibilityValue("\(Int(displayedProgress * 100)) percent")

            HStack {
                Text(time(audioPlayer.elapsed, when: isCurrent))
                Spacer()
                Button {
                    audioPlayer.toggle(track)
                } label: {
                    Image(systemName: isCurrent && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 58, height: 58)
                        .background(.white, in: Circle())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCurrent && audioPlayer.isPlaying ? "Pause" : "Play")
                Spacer()
                Text("−\(time(max(0, audioPlayer.duration - audioPlayer.elapsed), when: isCurrent))")
            }
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func time(_ interval: TimeInterval, when visible: Bool) -> String {
        let value = visible && interval.isFinite ? max(0, Int(interval)) : 0
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

#Preview {
    TrackPage(track: Track.samples[0])
        .environmentObject(AudioPlayer())
}
