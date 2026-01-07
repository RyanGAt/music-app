import { defineStore } from 'pinia';
import { supabase } from '../lib/supabase';

export type Profile = {
  id: string;
  display_name: string | null;
  avatar_url: string | null;
};

export const useAuthStore = defineStore('auth', {
  state: () => ({
    userId: '' as string,
    profile: null as Profile | null,
    ready: false,
    error: '' as string,
  }),
  actions: {
    async init() {
      try {
        const { data } = await supabase.auth.getSession();
        if (!data.session) {
          const { data: anonData, error } = await supabase.auth.signInAnonymously();
          if (error) throw error;
          this.userId = anonData.session?.user.id ?? '';
        } else {
          this.userId = data.session.user.id;
        }

        if (!this.userId) return;
        const { data: existing } = await supabase
          .from('profiles')
          .select('id, display_name, avatar_url')
          .eq('id', this.userId)
          .maybeSingle();

        if (!existing) {
          const displayName = `SoundScroller #${this.userId.slice(0, 5)}`;
          await supabase.from('profiles').insert({
            id: this.userId,
            display_name: displayName,
            avatar_url: null,
          });
          this.profile = { id: this.userId, display_name: displayName, avatar_url: null };
        } else {
          this.profile = existing;
        }
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to initialize auth';
      } finally {
        this.ready = true;
      }
    },
  },
});
