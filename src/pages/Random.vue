<template>
  <section class="stack">
    <div v-if="!supabaseConfigured" class="card error">
      Missing Supabase env. Add <code>VITE_SUPABASE_URL</code> and
      <code>VITE_SUPABASE_ANON_KEY</code> to <code>.env</code> and restart the dev server.
    </div>
    <div v-else-if="auth.error" class="card error">{{ auth.error }}</div>
    <div v-if="loading" class="card">Loading random tracks…</div>

    <div v-if="supabaseConfigured && !player.audioUnlocked" class="card">
      <p class="secondary">Tap to enable autoplay audio.</p>
      <button class="primary" @click="player.unlockAudio">Enable Audio</button>
    </div>

    <div v-if="supabaseConfigured" ref="feedContainer" class="feed-list">
      <div v-for="item in items" :key="item.track.id" :data-track-id="item.track.id">
        <RandomTrackItem
          :track="item.track"
          :like-count="item.likeCount"
          :comment-count="item.commentCount"
          :is-active="activeTrackId === item.track.id"
        />
      </div>
      <div v-if="loadingMore" class="card">Loading more tracks…</div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, nextTick, ref, watch } from 'vue';
import RandomTrackItem from '../components/RandomTrackItem.vue';
import { audiusProvider } from '../lib/audiusProvider';
import { supabase, supabaseConfigured } from '../lib/supabase';
import type { Track } from '../lib/musicProvider';
import { useAuthStore } from '../stores/auth';
import { usePlayerStore } from '../stores/player';

const auth = useAuthStore();
const player = usePlayerStore();

type RandomItem = {
  track: Track;
  likeCount: number;
  commentCount: number;
};

const items = ref<RandomItem[]>([]);
const loading = ref(false);
const loadingMore = ref(false);
const activeTrackId = ref<string | null>(null);
const feedContainer = ref<HTMLElement | null>(null);
const observer = ref<IntersectionObserver | null>(null);
const knownTrackIds = new Set<string>();

const fetchCounts = async (trackIds: string[]) => {
  const counts = new Map<string, { likeCount: number; commentCount: number }>();
  trackIds.forEach((id) => counts.set(id, { likeCount: 0, commentCount: 0 }));

  if (trackIds.length === 0 || !supabaseConfigured) return counts;

  const { data: posts } = await supabase
    .from('posts')
    .select('id, track_id')
    .in('track_id', trackIds)
    .eq('visibility', 'public');

  const postIds = posts?.map((post) => post.id) ?? [];
  if (postIds.length === 0) return counts;

  const { data: likes } = await supabase.from('likes').select('post_id').in('post_id', postIds);
  const { data: comments } = await supabase.from('comments').select('post_id').in('post_id', postIds);

  const likeCountsByPost = new Map<string, number>();
  likes?.forEach((like) => {
    likeCountsByPost.set(like.post_id, (likeCountsByPost.get(like.post_id) ?? 0) + 1);
  });

  const commentCountsByPost = new Map<string, number>();
  comments?.forEach((comment) => {
    commentCountsByPost.set(comment.post_id, (commentCountsByPost.get(comment.post_id) ?? 0) + 1);
  });

  const trackToPosts = new Map<string, string[]>();
  posts?.forEach((post) => {
    if (!post.track_id) return;
    if (!trackToPosts.has(post.track_id)) {
      trackToPosts.set(post.track_id, []);
    }
    trackToPosts.get(post.track_id)!.push(post.id);
  });

  trackToPosts.forEach((postIdsForTrack, trackId) => {
    const likeCount = postIdsForTrack.reduce(
      (total, postId) => total + (likeCountsByPost.get(postId) ?? 0),
      0,
    );
    const commentCount = postIdsForTrack.reduce(
      (total, postId) => total + (commentCountsByPost.get(postId) ?? 0),
      0,
    );
    counts.set(trackId, { likeCount, commentCount });
  });

  return counts;
};

const loadRandomTracks = async (count: number) => {
  if (loadingMore.value) return;
  loadingMore.value = true;
  try {
    const tracks = await audiusProvider.getRandomTracks(count);
    const unique = tracks.filter((track) => {
      if (knownTrackIds.has(track.id)) return false;
      knownTrackIds.add(track.id);
      return true;
    });
    if (unique.length === 0) return;

    const counts = await fetchCounts(unique.map((track) => track.id));
    items.value.push(
      ...unique.map((track) => {
        const meta = counts.get(track.id) ?? { likeCount: 0, commentCount: 0 };
        return {
          track,
          likeCount: meta.likeCount,
          commentCount: meta.commentCount,
        };
      }),
    );
  } finally {
    loadingMore.value = false;
  }
};

const setupObserver = () => {
  if (!feedContainer.value) return;
  observer.value?.disconnect();
  observer.value = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio);
      const top = visible[0];
      if (!top?.target) return;
      const id = (top.target as HTMLElement).dataset.trackId;
      if (!id) return;
      activeTrackId.value = id;
      const activeIndex = items.value.findIndex((item) => item.track.id === id);
      if (activeIndex >= items.value.length - 5) {
        loadRandomTracks(20);
      }
      const activeItem = items.value[activeIndex];
      if (activeItem) {
        playTrack(activeItem.track);
      }
    },
    { threshold: [0.5, 0.85] },
  );
  Array.from(feedContainer.value.children).forEach((child) => {
    const element = child as HTMLElement;
    observer.value?.observe(element);
  });
};

const playTrack = async (track: Track) => {
  if (!player.audioUnlocked) return;
  try {
    const played = await player.playTrack(track);
    if (!played) throw new Error('Playback failed');
  } catch (error) {
    console.warn('Skipping unplayable track', error);
    const currentIndex = items.value.findIndex((item) => item.track.id === track.id);
    const nextItem = items.value[currentIndex + 1];
    if (nextItem) {
      activeTrackId.value = nextItem.track.id;
      playTrack(nextItem.track);
    }
  }
};

onMounted(async () => {
  loading.value = true;
  await auth.init();
  await loadRandomTracks(40);
  loading.value = false;
  requestAnimationFrame(setupObserver);
});

watch(
  () => items.value.length,
  async () => {
    await nextTick();
    setupObserver();
  },
);

watch(
  () => player.audioUnlocked,
  (value) => {
    if (!value) return;
    const currentItem = items.value.find((item) => item.track.id === activeTrackId.value);
    if (currentItem) {
      playTrack(currentItem.track);
    }
  },
);

onBeforeUnmount(() => {
  observer.value?.disconnect();
  player.pause();
});
</script>

<style scoped>
.feed-list {
  height: 100vh;
  overflow-y: auto;
  scroll-snap-type: y mandatory;
  scrollbar-width: none;
  -ms-overflow-style: none;
}
.feed-list::-webkit-scrollbar {
  width: 0;
  height: 0;
}
.feed-list > * {
  min-height: 100vh;
  display: flex;
  align-items: center;
  scroll-snap-align: start;
  scroll-snap-stop: always;
}
.feed-list > * > * {
  width: 100%;
}
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
