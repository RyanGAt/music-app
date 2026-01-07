import type { MusicProvider, Track } from './musicProvider';

const DISCOVERY_HOST = 'https://api.audius.co';

const keywords = [
  'lofi',
  'chill',
  'ambient',
  'focus',
  'sleep',
  'beats',
  'hip hop',
  'house',
  'techno',
  'disco',
  'jazz',
  'soul',
  'guitar',
  'piano',
  'synth',
  'indie',
  'electronic',
  'dance',
  'workout',
  'acoustic',
  'instrumental',
  'vocal',
  'folk',
  'rock',
  'experimental',
  'soundtrack',
  'downtempo',
  'meditation',
  'city pop',
  'dream pop',
];

let cachedHost: string | null = null;

const pickRandom = <T>(items: T[]) => items[Math.floor(Math.random() * items.length)];

const fetchJson = async <T>(url: string): Promise<T> => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Audius request failed (${response.status})`);
  }
  return (await response.json()) as T;
};

const resolveHost = async () => {
  if (cachedHost) return cachedHost;
  const data = await fetchJson<{ data: string[] }>(DISCOVERY_HOST);
  const hosts = data.data ?? [];
  if (hosts.length === 0) {
    throw new Error('No Audius hosts available');
  }
  cachedHost = pickRandom(hosts);
  return cachedHost;
};

const getStreamUrl = async (host: string, id: string) => `${host}/v1/tracks/${id}/stream`;

type AudiusTrack = {
  id: string;
  title?: string;
  duration?: number;
  is_streamable?: boolean;
  permalink?: string;
  user?: { name?: string };
  artwork?: {
    '150x150'?: string;
    '480x480'?: string;
    '1000x1000'?: string;
  };
};

const isPlayable = (track: AudiusTrack) => track.is_streamable !== false;

const toTrack = async (host: string, track: AudiusTrack): Promise<Track | null> => {
  if (!track.id || !isPlayable(track)) return null;
  const streamUrl = await getStreamUrl(host, track.id);
  return {
    id: track.id,
    title: track.title ?? 'Untitled',
    artist: track.user?.name ?? 'Unknown',
    duration_ms: Math.round((track.duration ?? 0) * 1000),
    artwork_url: track.artwork?.['480x480'] ?? track.artwork?.['150x150'] ?? undefined,
    permalink_url: track.permalink ?? undefined,
    stream_url: streamUrl,
  };
};

const requestTracks = async (endpoint: string) => {
  const host = await resolveHost();
  const url = `${host}${endpoint}`;
  const data = await fetchJson<{ data: AudiusTrack[] }>(url);
  const tracks = await Promise.all((data.data ?? []).map((track) => toTrack(host, track)));
  return tracks.filter((track): track is Track => Boolean(track));
};

const getRandomTracks = async (count: number): Promise<Track[]> => {
  const results: Track[] = [];
  const attempts = Math.max(3, Math.ceil(count / 8));

  for (let attempt = 0; attempt < attempts && results.length < count; attempt += 1) {
    const useTrending = attempt % 2 === 0;
    try {
      if (useTrending) {
        const time = pickRandom(['week', 'month', 'year', 'all_time']);
        const offset = Math.floor(Math.random() * 200);
        const tracks = await requestTracks(`/v1/tracks/trending?time=${time}&limit=50&offset=${offset}`);
        results.push(...tracks);
      } else {
        const keyword = pickRandom(keywords);
        const offset = Math.floor(Math.random() * 200);
        const tracks = await requestTracks(
          `/v1/tracks/search?query=${encodeURIComponent(keyword)}&limit=50&offset=${offset}`,
        );
        results.push(...tracks);
      }
    } catch (error) {
      console.warn('Audius random fetch failed', error);
      cachedHost = null;
    }
  }

  return results.sort(() => 0.5 - Math.random()).slice(0, count);
};

const searchTracks = async (query: string): Promise<Track[]> => {
  if (!query.trim()) return [];
  try {
    return await requestTracks(`/v1/tracks/search?query=${encodeURIComponent(query)}&limit=20`);
  } catch (error) {
    console.warn('Audius search failed', error);
    cachedHost = null;
    return [];
  }
};

const getTrack = async (id: string): Promise<Track | null> => {
  try {
    const host = await resolveHost();
    const data = await fetchJson<{ data: AudiusTrack }>(`${host}/v1/tracks/${id}`);
    return await toTrack(host, data.data);
  } catch (error) {
    console.warn('Audius track fetch failed', error);
    cachedHost = null;
    return null;
  }
};

export const audiusProvider: MusicProvider = {
  getRandomTracks,
  searchTracks,
  getTrack,
};
