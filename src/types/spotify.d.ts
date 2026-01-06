declare namespace Spotify {
  type PlayerInit = {
    name: string;
    getOAuthToken: (cb: (token: string) => void) => void;
    volume?: number;
  };

  interface Player {
    connect: () => Promise<boolean>;
    disconnect: () => void;
    addListener: (event: string, cb: (data: any) => void) => void;
    setVolume: (volume: number) => Promise<void>;
  }

  const Player: new (options: PlayerInit) => Player;
}

interface Window {
  Spotify?: typeof Spotify;
  onSpotifyWebPlaybackSDKReady?: () => void;
}
