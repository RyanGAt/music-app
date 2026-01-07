import { defineStore } from 'pinia';
import type { Track } from '../lib/musicProvider';
import { HtmlAudioPlayerService } from '../lib/htmlAudioPlayerService';

const playerService = new HtmlAudioPlayerService();

export const usePlayerStore = defineStore('player', {
  state: () => ({
    ready: false,
    error: '' as string,
    audioUnlocked: false,
    currentTrackId: null as string | null,
  }),
  actions: {
    async init() {
      try {
        await playerService.init();
        this.ready = true;
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to init player';
      }
    },
    async unlockAudio() {
      this.audioUnlocked = true;
      await this.init();
    },
    async playTrack(track: Track, startMs?: number) {
      if (!this.audioUnlocked) return;
      if (!track.preview_url) return;
      if (this.currentTrackId === track.id) return;
      this.currentTrackId = track.id;
      await playerService.fadeTo(track, startMs);
    },
    async pause() {
      await playerService.pause();
    },
    setVolume(v: number) {
      playerService.setVolume(v);
    },
    getState() {
      return playerService.getState();
    },
  },
});
