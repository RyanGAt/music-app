import type { Track } from './musicProvider';

export interface PlayerService {
  init(): Promise<void>;
  play(track: Track, startMs?: number): Promise<void>;
  pause(): Promise<void>;
  fadeTo(track: Track, startMs?: number): Promise<void>;
  setVolume(v: number): void;
  getState(): { trackId?: string; isPlaying: boolean; positionMs: number };
}
