<template>
  <section class="stack">
    <div v-if="!supabaseConfigured" class="card error">
      Missing Supabase env. Add <code>VITE_SUPABASE_URL</code> and
      <code>VITE_SUPABASE_ANON_KEY</code> to <code>.env</code> and restart the dev server.
    </div>
    <div v-else-if="auth.error" class="card error">{{ auth.error }}</div>
    <div v-else-if="loading" class="card">Loading activity…</div>

    <div v-if="!loading && activity.length === 0" class="card">No activity yet.</div>

    <div class="stack">
      <div v-for="item in activity" :key="item.id" class="card activity-item">
        <div class="activity-header">
          <img v-if="item.trackArtwork" :src="item.trackArtwork" alt="" />
          <div>
            <div class="tag">{{ item.type === 'like' ? 'You liked' : 'You commented' }}</div>
            <div class="title">{{ item.trackTitle }}</div>
            <div class="secondary">{{ item.trackArtist }}</div>
          </div>
        </div>
        <div v-if="item.commentText" class="comment">“{{ item.commentText }}”</div>
        <div class="secondary time">{{ new Date(item.created_at).toLocaleString() }}</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { supabase, supabaseConfigured } from '../lib/supabase';
import { useAuthStore } from '../stores/auth';

type ActivityItem = {
  id: string;
  type: 'like' | 'comment';
  created_at: string;
  track_id: string;
  trackTitle: string;
  trackArtist: string;
  trackArtwork?: string;
  commentText?: string;
};

const auth = useAuthStore();
const loading = ref(false);
const activity = ref<ActivityItem[]>([]);

const loadActivity = async () => {
  if (!supabaseConfigured) return;
  loading.value = true;
  await auth.init();
  if (!auth.userId) {
    loading.value = false;
    return;
  }

  const { data: likes } = await supabase
    .from('likes')
    .select('id, created_at, post:posts!inner(id, track_id)')
    .eq('user_id', auth.userId)
    .order('created_at', { ascending: false })
    .limit(50);

  const { data: comments } = await supabase
    .from('comments')
    .select('id, text, created_at, post:posts!inner(id, track_id)')
    .eq('user_id', auth.userId)
    .order('created_at', { ascending: false })
    .limit(50);

  const trackIds = new Set<string>();
  likes?.forEach((like) => {
    if (like.post?.track_id) trackIds.add(like.post.track_id);
  });
  comments?.forEach((comment) => {
    if (comment.post?.track_id) trackIds.add(comment.post.track_id);
  });

  const { data: cachedTracks } = await supabase
    .from('tracks_cache')
    .select('id, title, artist, artwork_url')
    .in('id', [...trackIds]);

  const trackMap = new Map<string, { title: string; artist: string; artwork?: string }>();
  cachedTracks?.forEach((track) => {
    trackMap.set(track.id, { title: track.title, artist: track.artist, artwork: track.artwork_url ?? undefined });
  });

  const items: ActivityItem[] = [];

  likes?.forEach((like) => {
    const trackId = like.post?.track_id;
    if (!trackId) return;
    const meta = trackMap.get(trackId);
    items.push({
      id: `like-${like.id}`,
      type: 'like',
      created_at: like.created_at,
      track_id: trackId,
      trackTitle: meta?.title ?? `Track ${trackId.slice(0, 6)}`,
      trackArtist: meta?.artist ?? 'Unknown artist',
      trackArtwork: meta?.artwork,
    });
  });

  comments?.forEach((comment) => {
    const trackId = comment.post?.track_id;
    if (!trackId) return;
    const meta = trackMap.get(trackId);
    items.push({
      id: `comment-${comment.id}`,
      type: 'comment',
      created_at: comment.created_at,
      track_id: trackId,
      trackTitle: meta?.title ?? `Track ${trackId.slice(0, 6)}`,
      trackArtist: meta?.artist ?? 'Unknown artist',
      trackArtwork: meta?.artwork,
      commentText: comment.text ?? undefined,
    });
  });

  activity.value = items.sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at));
  loading.value = false;
};

onMounted(loadActivity);
</script>

<style scoped>
.activity-item {
  display: grid;
  gap: 6px;
}
.activity-header {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 12px;
  align-items: center;
}
.activity-header img {
  width: 56px;
  height: 56px;
  border-radius: 10px;
  object-fit: cover;
  border: 1px solid rgba(255, 255, 255, 0.12);
}
.tag {
  text-transform: uppercase;
  font-size: 0.7rem;
  letter-spacing: 0.08em;
  color: #a2a2b4;
}
.title {
  font-weight: 600;
}
.comment {
  font-style: italic;
}
.time {
  font-size: 0.75rem;
}
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
