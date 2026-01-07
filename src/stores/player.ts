import { defineStore } from 'pinia';
import type { Track } from '../lib/musicProvider';
import { HtmlAudioPlayerService } from '../lib/htmlAudioPlayerService';

const playerService = new HtmlAudioPlayerService();
let playChain: Promise<boolean> = Promise.resolve(true);
let playRequestId = 0;

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
      if (!this.audioUnlocked) return false;
      if (!track.stream_url) return false;
      this.currentTrackId = track.id;
      const requestId = (playRequestId += 1);
      playChain = playChain.then(async () => {
        if (requestId !== playRequestId) return false;
        try {
          await playerService.fadeTo(track, startMs);
          return true;
        } catch (error) {
          console.warn('Playback failed', error);
          return false;
        }
      });
      return playChain;
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
