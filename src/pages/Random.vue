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
          :liked="item.likedPostId !== null"
          @like="toggleLike(item)"
          @comment="openComments(item)"
        />
      </div>
      <div v-if="loadingMore" class="card">Loading more tracks…</div>
    </div>

    <CommentsModal
      v-if="commentsOpen"
      :comments="comments"
      @close="commentsOpen = false"
      @submit="submitComment"
    />
  </section>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, nextTick, ref, watch } from 'vue';
import RandomTrackItem from '../components/RandomTrackItem.vue';
import CommentsModal from '../components/CommentsModal.vue';
import { audiusProvider } from '../lib/audiusProvider';
import { supabase, supabaseConfigured } from '../lib/supabase';
import type { Track } from '../lib/musicProvider';
import { useAuthStore } from '../stores/auth';
import { usePlayerStore } from '../stores/player';
import { useRoute, useRouter } from 'vue-router';

const auth = useAuthStore();
const player = usePlayerStore();
const route = useRoute();
const router = useRouter();

type RandomItem = {
  track: Track;
  likeCount: number;
  commentCount: number;
  postId: string | null;
  likedPostId: string | null;
};

const items = ref<RandomItem[]>([]);
const loading = ref(false);
const loadingMore = ref(false);
const activeTrackId = ref<string | null>(null);
const feedContainer = ref<HTMLElement | null>(null);
const observer = ref<IntersectionObserver | null>(null);
const knownTrackIds = new Set<string>();
const pausedForScroll = ref(false);
const pausedTrackId = ref<string | null>(null);
const commentsOpen = ref(false);
const comments = ref<
  {
    id: string;
    text: string;
    created_at: string;
    profiles?: { display_name: string | null; avatar_url: string | null } | null;
  }[]
>([]);
const activeItem = ref<RandomItem | null>(null);

const upsertTrackCache = async (track: Track) => {
  await supabase.from('tracks_cache').upsert(
    {
      id: track.id,
      source: 'audius',
      title: track.title,
      artist: track.artist,
      duration_ms: track.duration_ms,
      artwork_url: track.artwork_url ?? null,
      permalink_url: track.permalink_url ?? null,
      stream_url: track.stream_url ?? null,
      last_fetched_at: new Date().toISOString(),
    },
    { onConflict: 'id' },
  );
};

const fetchMeta = async (trackIds: string[]) => {
  const counts = new Map<
    string,
    { likeCount: number; commentCount: number; postId: string | null; likedPostId: string | null }
  >();
  trackIds.forEach((id) => counts.set(id, { likeCount: 0, commentCount: 0, postId: null, likedPostId: null }));

  if (trackIds.length === 0 || !supabaseConfigured) return counts;

  const { data: posts } = await supabase
    .from('posts')
    .select('id, track_id, created_at')
    .in('track_id', trackIds)
    .eq('visibility', 'public')
    .eq('type', 'auto_moment')
    .order('created_at', { ascending: false });

  const postIds = posts?.map((post) => post.id) ?? [];
  if (postIds.length === 0) return counts;

  const { data: likes } = await supabase.from('likes').select('post_id, user_id').in('post_id', postIds);
  const { data: comments } = await supabase.from('comments').select('post_id').in('post_id', postIds);
  const { data: userLikes } = await supabase
    .from('likes')
    .select('post_id')
    .eq('user_id', auth.userId)
    .in('post_id', postIds);

  const likeCountsByPost = new Map<string, number>();
  likes?.forEach((like) => {
    likeCountsByPost.set(like.post_id, (likeCountsByPost.get(like.post_id) ?? 0) + 1);
  });

  const commentCountsByPost = new Map<string, number>();
  comments?.forEach((comment) => {
    commentCountsByPost.set(comment.post_id, (commentCountsByPost.get(comment.post_id) ?? 0) + 1);
  });

  const trackToPosts = new Map<string, string[]>();
  const postToTrack = new Map<string, string>();
  posts?.forEach((post) => {
    if (!post.track_id) return;
    postToTrack.set(post.id, post.track_id);
    if (!trackToPosts.has(post.track_id)) {
      trackToPosts.set(post.track_id, []);
    }
    trackToPosts.get(post.track_id)!.push(post.id);
  });

  const likedPostIdsByTrack = new Map<string, string>();
  userLikes?.forEach((like) => {
    const trackId = postToTrack.get(like.post_id);
    if (trackId && !likedPostIdsByTrack.has(trackId)) {
      likedPostIdsByTrack.set(trackId, like.post_id);
    }
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
    counts.set(trackId, {
      likeCount,
      commentCount,
      postId: postIdsForTrack[0] ?? null,
      likedPostId: likedPostIdsByTrack.get(trackId) ?? null,
    });
  });

  return counts;
};

const refreshItemMeta = async (trackId: string) => {
  const meta = await fetchMeta([trackId]);
  const update = meta.get(trackId);
  if (!update) return;
  const item = items.value.find((entry) => entry.track.id === trackId);
  if (!item) return;
  item.likeCount = update.likeCount;
  item.commentCount = update.commentCount;
  item.postId = update.postId;
  item.likedPostId = update.likedPostId;
};

const ensurePostForTrack = async (item: RandomItem) => {
  if (item.postId) return item.postId;
  const maxStart = Math.max(0, item.track.duration_ms - 15000);
  const startMs = maxStart > 0 ? Math.floor(Math.random() * maxStart) : 0;
  const createdAt = new Date().toISOString();
  const { data } = await supabase
    .from('posts')
    .insert({
      user_id: auth.userId,
      type: 'auto_moment',
      source: 'audius',
      track_id: item.track.id,
      start_ms: startMs,
      text: null,
      visibility: 'public',
      created_at: createdAt,
    })
    .select('id')
    .single();
  if (!data?.id) return item.postId;
  await upsertTrackCache(item.track);
  item.postId = data.id;
  return data.id;
};

const toggleLike = async (item: RandomItem) => {
  if (!supabaseConfigured || !auth.userId) return;
  if (!auth.profileComplete) {
    await router.push({ path: '/profile', query: { notice: 'complete', next: route.fullPath } });
    return;
  }
  const postId = await ensurePostForTrack(item);
  if (!postId) return;
  if (item.likedPostId) {
    await supabase.from('likes').delete().eq('post_id', item.likedPostId).eq('user_id', auth.userId);
  } else {
    await supabase.from('likes').insert({ post_id: postId, user_id: auth.userId });
  }
  await refreshItemMeta(item.track.id);
};

const loadComments = async (postId: string) => {
  const { data } = await supabase
    .from('comments')
    .select('id, text, created_at, profiles:profiles!comments_user_id_fkey(display_name, avatar_url)')
    .eq('post_id', postId)
    .order('created_at', { ascending: false });
  comments.value = data ?? [];
};

const openComments = async (item: RandomItem) => {
  if (!supabaseConfigured || !auth.userId) return;
  if (!auth.profileComplete) {
    await router.push({ path: '/profile', query: { notice: 'complete', next: route.fullPath } });
    return;
  }
  const postId = await ensurePostForTrack(item);
  if (!postId) return;
  activeItem.value = item;
  commentsOpen.value = true;
  await loadComments(postId);
};

const submitComment = async (text: string) => {
  if (!activeItem.value || text.trim().length === 0) return;
  if (!supabaseConfigured || !auth.userId) return;
  if (!auth.profileComplete) {
    await router.push({ path: '/profile', query: { notice: 'complete', next: route.fullPath } });
    return;
  }
  const postId = await ensurePostForTrack(activeItem.value);
  if (!postId) return;
  await supabase.from('comments').insert({ post_id: postId, user_id: auth.userId, text: text.trim() });
  commentsOpen.value = false;
  await refreshItemMeta(activeItem.value.track.id);
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

    const counts = await fetchMeta(unique.map((track) => track.id));
    items.value.push(
      ...unique.map((track) => {
        const meta = counts.get(track.id) ?? {
          likeCount: 0,
          commentCount: 0,
          postId: null,
          likedPostId: null,
        };
        return {
          track,
          likeCount: meta.likeCount,
          commentCount: meta.commentCount,
          postId: meta.postId,
          likedPostId: meta.likedPostId,
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
      if (activeTrackId.value === id) return;
      activeTrackId.value = id;
      const activeIndex = items.value.findIndex((item) => item.track.id === id);
      if (activeIndex >= items.value.length - 5) {
        loadRandomTracks(20);
      }
      const activeItem = items.value[activeIndex];
      if (activeItem) {
        const shouldReplayPaused =
          pausedForScroll.value && pausedTrackId.value === activeItem.track.id;
        if (player.currentTrackId === activeItem.track.id && !shouldReplayPaused) return;
        pausedForScroll.value = false;
        pausedTrackId.value = null;
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

const handleScroll = () => {
  if (!player.audioUnlocked) return;
  const state = player.getState();
  if (!state.isPlaying) return;
  pausedForScroll.value = true;
  pausedTrackId.value = player.currentTrackId;
  void player.pause();
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
  await nextTick();
  feedContainer.value?.addEventListener('scroll', handleScroll, { passive: true });
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
  feedContainer.value?.removeEventListener('scroll', handleScroll);
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
