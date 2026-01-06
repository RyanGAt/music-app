const TOKEN_KEY = 'soundscroll_spotify_tokens';
const VERIFIER_KEY = 'soundscroll_pkce_verifier';
const STATE_KEY = 'soundscroll_pkce_state';

export type SpotifyTokens = {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
};

export type SpotifyTrack = {
  id: string;
  name: string;
  artists: { name: string }[];
  album: { images: { url: string }[] };
  preview_url: string | null;
};

const clientId = import.meta.env.VITE_SPOTIFY_CLIENT_ID as string;
const redirectUri = import.meta.env.VITE_SPOTIFY_REDIRECT_URI as string;

const scopes = [
  'streaming',
  'user-read-email',
  'user-read-private',
  'user-read-playback-state',
  'user-modify-playback-state',
];

const encoder = new TextEncoder();

const base64UrlEncode = (value: ArrayBuffer) => {
  return btoa(String.fromCharCode(...new Uint8Array(value)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
};

const sha256 = async (plain: string) => {
  const data = encoder.encode(plain);
  return crypto.subtle.digest('SHA-256', data);
};

const generateVerifier = () => {
  const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  let verifier = '';
  for (let i = 0; i < 96; i += 1) {
    verifier += possible.charAt(Math.floor(Math.random() * possible.length));
  }
  return verifier;
};

export const getStoredTokens = (): SpotifyTokens | null => {
  const raw = localStorage.getItem(TOKEN_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as SpotifyTokens;
  } catch {
    return null;
  }
};

export const setStoredTokens = (tokens: SpotifyTokens | null) => {
  if (!tokens) {
    localStorage.removeItem(TOKEN_KEY);
    return;
  }
  localStorage.setItem(TOKEN_KEY, JSON.stringify(tokens));
};

export const createLoginUrl = async () => {
  const verifier = generateVerifier();
  const challenge = base64UrlEncode(await sha256(verifier));
  const state = crypto.randomUUID();
  localStorage.setItem(VERIFIER_KEY, verifier);
  localStorage.setItem(STATE_KEY, state);

  const params = new URLSearchParams({
    response_type: 'code',
    client_id: clientId,
    scope: scopes.join(' '),
    redirect_uri: redirectUri,
    state,
    code_challenge_method: 'S256',
    code_challenge: challenge,
  });

  return `https://accounts.spotify.com/authorize?${params.toString()}`;
};

export const exchangeCodeForToken = async (code: string) => {
  const verifier = localStorage.getItem(VERIFIER_KEY);
  if (!verifier) throw new Error('Missing PKCE verifier');

  const body = new URLSearchParams({
    client_id: clientId,
    grant_type: 'authorization_code',
    code,
    redirect_uri: redirectUri,
    code_verifier: verifier,
  });

  const response = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  if (!response.ok) {
    throw new Error('Failed to exchange Spotify code');
  }

  const data = await response.json();
  const tokens: SpotifyTokens = {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  };
  setStoredTokens(tokens);
  return tokens;
};

export const refreshAccessToken = async (refreshToken: string) => {
  const body = new URLSearchParams({
    client_id: clientId,
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
  });

  const response = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  if (!response.ok) {
    throw new Error('Failed to refresh Spotify token');
  }

  const data = await response.json();
  const existing = getStoredTokens();
  const tokens: SpotifyTokens = {
    accessToken: data.access_token,
    refreshToken: data.refresh_token ?? existing?.refreshToken ?? '',
    expiresAt: Date.now() + data.expires_in * 1000,
  };
  setStoredTokens(tokens);
  return tokens;
};

export const ensureValidToken = async () => {
  const stored = getStoredTokens();
  if (!stored) return null;
  if (stored.expiresAt > Date.now() + 60_000) {
    return stored;
  }
  return refreshAccessToken(stored.refreshToken);
};

export const spotifyFetch = async (endpoint: string, options: RequestInit = {}) => {
  const tokens = await ensureValidToken();
  if (!tokens) throw new Error('Missing Spotify token');
  const response = await fetch(`https://api.spotify.com/v1${endpoint}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${tokens.accessToken}`,
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
  if (!response.ok) {
    throw new Error(`Spotify API error: ${response.status}`);
  }
  return response.json();
};

export const getMe = async () => spotifyFetch('/me');

export const searchTracks = async (query: string) => {
  const data = await spotifyFetch(`/search?type=track&limit=8&q=${encodeURIComponent(query)}`);
  return data.tracks.items as SpotifyTrack[];
};

export const getTrack = async (trackId: string) => {
  const data = await spotifyFetch(`/tracks/${trackId}`);
  return data as SpotifyTrack;
};

export const getStoredState = () => localStorage.getItem(STATE_KEY);

export const clearStoredState = () => {
  localStorage.removeItem(STATE_KEY);
  localStorage.removeItem(VERIFIER_KEY);
};
