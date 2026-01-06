type PlayerStatus = {
  deviceId: string | null;
  ready: boolean;
  error?: string;
};

declare global {
  interface Window {
    onSpotifyWebPlaybackSDKReady?: () => void;
    Spotify?: typeof Spotify;
  }
}

let sdkPromise: Promise<void> | null = null;

export const loadSpotifySdk = () => {
  if (sdkPromise) return sdkPromise;
  sdkPromise = new Promise((resolve, reject) => {
    const existing = document.getElementById('spotify-sdk');
    if (existing) {
      resolve();
      return;
    }
    const script = document.createElement('script');
    script.id = 'spotify-sdk';
    script.src = 'https://sdk.scdn.co/spotify-player.js';
    script.async = true;
    script.onerror = () => reject(new Error('Failed to load Spotify SDK'));
    window.onSpotifyWebPlaybackSDKReady = () => resolve();
    document.body.appendChild(script);
  });
  return sdkPromise;
};

export const createSpotifyPlayer = async (token: string, onState: (status: PlayerStatus) => void) => {
  await loadSpotifySdk();
  if (!window.Spotify) throw new Error('Spotify SDK not ready');

  return new Promise<Spotify.Player>((resolve, reject) => {
    const player = new window.Spotify.Player({
      name: 'SoundScroll',
      getOAuthToken: (cb) => cb(token),
      volume: 0.8,
    });

    player.addListener('ready', ({ device_id }) => {
      onState({ deviceId: device_id, ready: true });
      resolve(player);
    });
    player.addListener('not_ready', ({ device_id }) => {
      onState({ deviceId: device_id, ready: false, error: 'Device offline' });
    });
    player.addListener('initialization_error', ({ message }) => {
      onState({ deviceId: null, ready: false, error: message });
      reject(new Error(message));
    });
    player.addListener('authentication_error', ({ message }) => {
      onState({ deviceId: null, ready: false, error: message });
      reject(new Error(message));
    });
    player.addListener('account_error', ({ message }) => {
      onState({ deviceId: null, ready: false, error: message });
      reject(new Error(message));
    });

    player.connect();
  });
};

export const fadeVolume = async (
  setter: (value: number) => Promise<void> | void,
  from: number,
  to: number,
  duration = 350,
) => {
  const steps = 12;
  const stepTime = duration / steps;
  for (let i = 0; i <= steps; i += 1) {
    const value = from + ((to - from) * i) / steps;
    await setter(Math.max(0, Math.min(1, value)));
    await new Promise((resolve) => setTimeout(resolve, stepTime));
  }
};

export const playOnDevice = async (
  accessToken: string,
  deviceId: string,
  trackId: string,
  startMs?: number,
) => {
  const body = {
    uris: [`spotify:track:${trackId}`],
    position_ms: startMs ?? 0,
  };

  await fetch(`https://api.spotify.com/v1/me/player/play?device_id=${deviceId}`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
};
