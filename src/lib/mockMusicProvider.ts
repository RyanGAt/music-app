import type { MusicProvider, Track } from './musicProvider';
import catalog from '../mock/catalog.json';

const tracks = catalog as Track[];

export class MockMusicProvider implements MusicProvider {
  async searchTracks(query: string): Promise<Track[]> {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return [];
    return tracks
      .filter((track) => {
        return (
          track.title.toLowerCase().includes(normalized) ||
          track.artist.toLowerCase().includes(normalized)
        );
      })
      .slice(0, 8);
  }

  async getTrack(id: string): Promise<Track | null> {
    return tracks.find((track) => track.id === id) ?? null;
  }
}

export const mockMusicProvider = new MockMusicProvider();
