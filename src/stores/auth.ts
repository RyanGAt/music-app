import { defineStore } from 'pinia';
import { supabase } from '../lib/supabase';
import {
  createLoginUrl,
  exchangeCodeForToken,
  getMe,
  getStoredState,
  getStoredTokens,
  setStoredTokens,
  clearStoredState,
  type SpotifyTokens,
} from '../lib/spotify';

export type SpotifyProfile = {
  id: string;
  display_name: string;
  images: { url: string }[];
  product?: string;
};

export const useAuthStore = defineStore('auth', {
  state: () => ({
    userId: '' as string,
    spotifyTokens: getStoredTokens() as SpotifyTokens | null,
    spotifyProfile: null as SpotifyProfile | null,
    spotifyReady: false,
    error: '' as string,
  }),
  getters: {
    isPremium: (state) => state.spotifyProfile?.product === 'premium',
    isSpotifyAuthed: (state) => Boolean(state.spotifyTokens?.accessToken),
  },
  actions: {
    async init() {
      const { data } = await supabase.auth.getSession();
      if (!data.session) {
        const { data: anonData, error } = await supabase.auth.signInAnonymously();
        if (error) throw error;
        this.userId = anonData.session?.user.id ?? '';
      } else {
        this.userId = data.session.user.id;
      }

      await this.handleSpotifyCallback();
      if (this.spotifyTokens) {
        await this.fetchSpotifyProfile();
      }
    },
    async handleSpotifyCallback() {
      const url = new URL(window.location.href);
      const code = url.searchParams.get('code');
      const state = url.searchParams.get('state');
      const storedState = getStoredState();
      if (!code || !state || state !== storedState) {
        return;
      }
      try {
        this.spotifyTokens = await exchangeCodeForToken(code);
        clearStoredState();
        url.searchParams.delete('code');
        url.searchParams.delete('state');
        window.history.replaceState({}, '', url.toString());
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Spotify auth failed';
      }
    },
    async loginWithSpotify() {
      const url = await createLoginUrl();
      window.location.assign(url);
    },
    async fetchSpotifyProfile() {
      try {
        const profile = await getMe();
        this.spotifyProfile = profile;
        await supabase.from('profiles').upsert({
          id: this.userId,
          spotify_user_id: profile.id,
          display_name: profile.display_name,
          avatar_url: profile.images?.[0]?.url ?? null,
        });
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to load Spotify profile';
      } finally {
        this.spotifyReady = true;
      }
    },
    logoutSpotify() {
      setStoredTokens(null);
      this.spotifyTokens = null;
      this.spotifyProfile = null;
    },
  },
});
