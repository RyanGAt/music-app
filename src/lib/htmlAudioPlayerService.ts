import type { Track } from './musicProvider';
import type { PlayerService } from './playerService';

const clamp = (value: number, min = 0, max = 1) => Math.min(max, Math.max(min, value));

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export class HtmlAudioPlayerService implements PlayerService {
  private audioContext: AudioContext | null = null;
  private current:
    | {
        audio: HTMLAudioElement;
        source: MediaElementAudioSourceNode;
        gain: GainNode;
        trackId: string;
      }
    | null = null;
  private volume = 0.85;
  private isPlaying = false;
  private positionMs = 0;

  async init(): Promise<void> {
    if (!this.audioContext) {
      this.audioContext = new AudioContext();
    }
    if (this.audioContext.state === 'suspended') {
      await this.audioContext.resume();
    }
  }

  setVolume(v: number) {
    this.volume = clamp(v);
    if (this.current) {
      this.current.gain.gain.value = this.volume;
    }
  }

  getState() {
    return {
      trackId: this.current?.trackId,
      isPlaying: this.isPlaying,
      positionMs: this.positionMs,
    };
  }

  private async seekIfPossible(audio: HTMLAudioElement, startMs?: number) {
    if (!startMs || startMs <= 0) return;
    const target = startMs / 1000;

    try {
      audio.currentTime = Math.min(target, audio.duration || target);
    } catch (error) {
      console.warn('Seek failed', error);
    }
  }

  private createNode(track: Track, startMs?: number) {
    if (!this.audioContext) throw new Error('Audio context not initialized');
    if (!track.stream_url) throw new Error('Missing stream URL');

    const audio = new Audio();
    audio.crossOrigin = 'anonymous';
    audio.preload = 'auto';
    audio.src = track.stream_url;

    audio.addEventListener('timeupdate', () => {
      this.positionMs = audio.currentTime * 1000;
    });

    void this.seekIfPossible(audio, startMs);

    const source = this.audioContext.createMediaElementSource(audio);
    const gain = this.audioContext.createGain();
    gain.gain.value = 0;
    source.connect(gain).connect(this.audioContext.destination);
    return { audio, source, gain, trackId: track.id };
  }

  private async fade(gain: GainNode, from: number, to: number, duration = 320) {
    const steps = 12;
    const stepTime = duration / steps;
    for (let i = 0; i <= steps; i += 1) {
      const value = from + ((to - from) * i) / steps;
      gain.gain.value = clamp(value);
      await sleep(stepTime);
    }
  }

  private cleanupCurrent() {
    if (!this.current) return;
    this.current.audio.pause();
    this.current.audio.src = '';
  }

  async play(track: Track, startMs?: number) {
    await this.init();
    if (!track.stream_url) return;
    this.cleanupCurrent();
    this.current = this.createNode(track, startMs);
    await this.current.audio.play();
    this.isPlaying = true;
    this.current.gain.gain.value = this.volume;
  }

  async pause() {
    if (this.current) {
      this.current.audio.pause();
    }
    this.isPlaying = false;
  }

  async fadeTo(track: Track, startMs?: number) {
    await this.init();
    if (!track.stream_url) return;

    const next = this.createNode(track, startMs);
    await next.audio.play();

    if (!this.current) {
      await this.fade(next.gain, 0, this.volume, 260);
      this.current = next;
      this.isPlaying = true;
      return;
    }

    const previous = this.current;
    await Promise.all([
      this.fade(previous.gain, previous.gain.gain.value, 0, 300),
      this.fade(next.gain, 0, this.volume, 320),
    ]);

    previous.audio.pause();
    previous.audio.src = '';
    this.current = next;
    this.isPlaying = true;
  }
}
