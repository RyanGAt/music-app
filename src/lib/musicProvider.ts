export type Track = {
  id: string;
  title: string;
  artist: string;
  duration_ms: number;
  artwork_url?: string;
  permalink_url?: string;
  stream_url?: string;
};

export interface MusicProvider {
  getRandomTracks(count: number): Promise<Track[]>;
  searchTracks(query: string): Promise<Track[]>;
  getTrack(id: string): Promise<Track | null>;
}
