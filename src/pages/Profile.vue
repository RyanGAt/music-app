<template>
  <section class="stack">
    <div v-if="!supabaseConfigured" class="card error">
      Missing Supabase env. Add <code>VITE_SUPABASE_URL</code> and
      <code>VITE_SUPABASE_ANON_KEY</code> to <code>.env</code> and restart the dev server.
    </div>
    <div v-else-if="auth.error" class="card error">{{ auth.error }}</div>
    <div v-else-if="!auth.userId" class="card stack">
      <h2>Sign in required</h2>
      <p class="secondary">Sign in to view your profile and likes.</p>
      <RouterLink class="primary" to="/auth">Go to sign in</RouterLink>
    </div>
    <div v-else class="stack">
      <div class="card profile">
        <img v-if="auth.profile?.avatar_url" :src="auth.profile.avatar_url" alt="" />
        <div>
          <h2>{{ auth.profile?.display_name || 'SoundScroller' }}</h2>
          <p class="secondary">{{ shortId }}</p>
          <div class="profile-actions">
            <RouterLink class="ghost" to="/profile/setup">Edit profile</RouterLink>
            <RouterLink class="ghost" to="/activity">View activity</RouterLink>
          </div>
        </div>
      </div>

      <div class="card">
        <h3>Liked tracks</h3>
        <p class="secondary">Tracks you've liked are saved here.</p>
      </div>

      <div v-if="loading" class="card">Loading likes…</div>
      <div v-else-if="likedTracks.length === 0" class="card">No likes yet.</div>
      <div v-else class="stack">
        <div v-for="item in likedTracks" :key="item.id" class="card liked-item">
          <img v-if="item.artwork" :src="item.artwork" alt="" />
          <div>
            <div class="title">{{ item.title }}</div>
            <div class="secondary">{{ item.artist }}</div>
            <div class="secondary time">{{ new Date(item.createdAt).toLocaleString() }}</div>
            <a v-if="item.permalink" :href="item.permalink" target="_blank" rel="noreferrer">
              Open on Audius
            </a>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { supabase, supabaseConfigured } from '../lib/supabase';
import { useAuthStore } from '../stores/auth';

type LikedTrack = {
  id: string;
  trackId: string;
  title: string;
  artist: string;
  artwork?: string;
  permalink?: string;
  createdAt: string;
};

const auth = useAuthStore();
const loading = ref(false);
const likedTracks = ref<LikedTrack[]>([]);

const shortId = computed(() => {
  if (!auth.userId) return '';
  return `id: ${auth.userId.slice(0, 8)}`;
});

const loadLikes = async () => {
  if (!supabaseConfigured || !auth.userId) return;
  loading.value = true;
  const { data: likes } = await supabase
    .from('likes')
    .select('created_at, post:posts!inner(track_id)')
    .eq('user_id', auth.userId)
    .order('created_at', { ascending: false })
    .limit(50);

  const trackIds = likes?.map((like) => like.post?.track_id).filter(Boolean) as string[] | undefined;
  if (!trackIds || trackIds.length === 0) {
    likedTracks.value = [];
    loading.value = false;
    return;
  }

  const { data: cachedTracks } = await supabase
    .from('tracks_cache')
    .select('id, title, artist, artwork_url, permalink_url')
    .in('id', trackIds);

  const trackMap = new Map<string, { title: string; artist: string; artwork?: string; permalink?: string }>();
  cachedTracks?.forEach((track) => {
    trackMap.set(track.id, {
      title: track.title,
      artist: track.artist,
      artwork: track.artwork_url ?? undefined,
      permalink: track.permalink_url ?? undefined,
    });
  });

  likedTracks.value =
    likes?.map((like) => {
      const trackId = like.post?.track_id ?? '';
      const meta = trackMap.get(trackId);
      return {
        id: `${trackId}-${like.created_at}`,
        trackId,
        title: meta?.title ?? `Track ${trackId.slice(0, 6)}`,
        artist: meta?.artist ?? 'Unknown artist',
        artwork: meta?.artwork,
        permalink: meta?.permalink,
        createdAt: like.created_at,
      };
    }) ?? [];
  loading.value = false;
};

onMounted(async () => {
  await auth.init();
  if (auth.userId) {
    await loadLikes();
  }
});
</script>

<style scoped>
.profile {
  display: flex;
  gap: 16px;
  align-items: center;
}
.profile img {
  width: 64px;
  height: 64px;
  border-radius: 50%;
}
.profile-actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-top: 8px;
}
.liked-item {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 12px;
  align-items: center;
}
.liked-item img {
  width: 56px;
  height: 56px;
  border-radius: 10px;
  object-fit: cover;
  border: 1px solid rgba(255, 255, 255, 0.12);
}
.title {
  font-weight: 600;
}
.time {
  font-size: 0.75rem;
}
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
