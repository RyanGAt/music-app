import { defineStore } from 'pinia';
import { supabase, supabaseConfigured } from '../lib/supabase';

export type Profile = {
  id: string;
  display_name: string | null;
  avatar_url: string | null;
};

const isProfileComplete = (profile: Profile | null) => {
  const name = profile?.display_name?.trim() ?? '';
  return name.length >= 2 && name.length <= 24;
};

export const useAuthStore = defineStore('auth', {
  state: () => ({
    userId: '' as string,
    email: '' as string,
    profile: null as Profile | null,
    profileComplete: false,
    ready: false,
    error: '' as string,
    loading: false,
  }),
  actions: {
    async init() {
      try {
        if (!supabaseConfigured) {
          this.error = 'Missing Supabase environment variables.';
          this.ready = true;
          return;
        }
        const { data, error } = await supabase.auth.getSession();
        if (error) throw error;
        const session = data.session;
        if (session?.user) {
          this.userId = session.user.id;
          this.email = session.user.email ?? '';
          await this.fetchProfile();
        } else {
          this.userId = '';
          this.email = '';
          this.profile = null;
          this.profileComplete = false;
        }
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to initialize auth';
      } finally {
        this.ready = true;
      }
    },
    async fetchProfile() {
      if (!this.userId) return;
      const { data: existing, error } = await supabase
        .from('profiles')
        .select('id, display_name, avatar_url')
        .eq('id', this.userId)
        .maybeSingle();
      if (error) throw error;
      this.profile = existing ?? null;
      this.profileComplete = isProfileComplete(this.profile);
    },
    async signIn(email: string, password: string) {
      this.loading = true;
      this.error = '';
      try {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        this.userId = data.user?.id ?? '';
        this.email = data.user?.email ?? email;
        await this.fetchProfile();
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to sign in';
        throw error;
      } finally {
        this.loading = false;
        this.ready = true;
      }
    },
    async signUp(email: string, password: string) {
      this.loading = true;
      this.error = '';
      try {
        const { data, error } = await supabase.auth.signUp({ email, password });
        if (error) throw error;
        this.userId = data.user?.id ?? '';
        this.email = data.user?.email ?? email;
        await this.fetchProfile();
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to sign up';
        throw error;
      } finally {
        this.loading = false;
        this.ready = true;
      }
    },
    async signOut() {
      this.loading = true;
      this.error = '';
      try {
        const { error } = await supabase.auth.signOut();
        if (error) throw error;
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to sign out';
        throw error;
      } finally {
        this.userId = '';
        this.email = '';
        this.profile = null;
        this.profileComplete = false;
        this.loading = false;
        this.ready = true;
      }
    },
  },
});
