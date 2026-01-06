import { defineStore } from 'pinia';
import { ensureValidToken } from '../lib/spotify';
import { createSpotifyPlayer, fadeVolume, playOnDevice } from '../lib/player';

export const usePlayerStore = defineStore('player', {
  state: () => ({
    deviceId: null as string | null,
    ready: false,
    error: '' as string,
    previewMode: false,
    audioUnlocked: false,
    currentTrackId: null as string | null,
    previewAudio: null as HTMLAudioElement | null,
    player: null as Spotify.Player | null,
  }),
  actions: {
    unlockAudio() {
      this.audioUnlocked = true;
    },
    async initPlayer(isPremium: boolean) {
      this.previewMode = !isPremium;
      if (!isPremium) return;
      const tokens = await ensureValidToken();
      if (!tokens) {
        this.error = 'Missing Spotify token.';
        return;
      }
      try {
        this.player = await createSpotifyPlayer(tokens.accessToken, (status) => {
          this.deviceId = status.deviceId;
          this.ready = status.ready;
          if (status.error) this.error = status.error;
        });
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to init player';
        this.previewMode = true;
      }
    },
    async fadeAndPlaySpotify(trackId: string, startMs?: number) {
      if (!this.deviceId) return;
      const tokens = await ensureValidToken();
      if (!tokens) return;
      await fadeVolume((v) => this.player?.setVolume(v), 0.8, 0, 280);
      await playOnDevice(tokens.accessToken, this.deviceId, trackId, startMs);
      await fadeVolume((v) => this.player?.setVolume(v), 0, 0.8, 320);
    },
    async fadeAndPlayPreview(url: string, startMs?: number) {
      if (this.previewAudio && !this.previewAudio.paused) {
        await fadeVolume((v) => {
          this.previewAudio!.volume = v;
        }, this.previewAudio.volume, 0, 200);
        this.previewAudio.pause();
      }
      this.previewAudio = new Audio(url);
      this.previewAudio.volume = 0;
      if (startMs && startMs > 0) {
        this.previewAudio.currentTime = Math.min(startMs / 1000, 25);
      }
      await this.previewAudio.play();
      await fadeVolume((v) => {
        if (this.previewAudio) this.previewAudio.volume = v;
      }, 0, 0.85, 320);
    },
    async playTrack({
      trackId,
      previewUrl,
      startMs,
    }: {
      trackId: string;
      previewUrl: string | null;
      startMs?: number;
    }) {
      if (!this.audioUnlocked) return;
      if (this.currentTrackId === trackId) return;
      this.currentTrackId = trackId;
      if (this.previewMode || !this.deviceId) {
        if (previewUrl) {
          await this.fadeAndPlayPreview(previewUrl, startMs);
        }
        return;
      }
      await this.fadeAndPlaySpotify(trackId, startMs);
    },
    stop() {
      if (this.previewAudio) {
        this.previewAudio.pause();
      }
    },
  },
});
