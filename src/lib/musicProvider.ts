export type Track = {
  id: string;
  title: string;
  artist: string;
  duration_ms: number;
  preview_url: string;
};

export interface MusicProvider {
  searchTracks(query: string): Promise<Track[]>;
  getTrack(id: string): Promise<Track | null>;
}
