<template>
  <section class="stack">
    <div v-if="!supabaseConfigured" class="card error">
      Missing Supabase env. Add <code>VITE_SUPABASE_URL</code> and
      <code>VITE_SUPABASE_ANON_KEY</code> to <code>.env</code> and restart the dev server.
    </div>
    <div v-else-if="auth.error" class="card error">{{ auth.error }}</div>
    <div v-if="feed.loading" class="card">Loading feed…</div>

    <div v-if="supabaseConfigured && !player.audioUnlocked" class="card">
      <p class="secondary">Tap to enable autoplay audio.</p>
      <button class="primary" @click="player.unlockAudio">Enable Audio</button>
    </div>

    <div v-if="supabaseConfigured" class="card sort-toggle">
      <span class="secondary">Sort</span>
      <button
        class="ghost"
        :class="{ active: feed.sortMode === 'latest' }"
        type="button"
        @click="feed.setSortMode('latest')"
      >
        Latest
      </button>
      <button
        class="ghost"
        :class="{ active: feed.sortMode === 'popular' }"
        type="button"
        @click="feed.setSortMode('popular')"
      >
        Popular
      </button>
    </div>

    <div v-if="supabaseConfigured" ref="feedContainer" class="feed-list">
      <div v-for="post in feed.posts" :key="post.id" :data-post-id="post.id">
        <FeedItem
          :post="post"
          :track="trackFor(post)"
          :is-active="feed.activePostId === post.id"
          :liked="likedPostIds().has(post.id)"
          @like="toggleLike(post)"
          @comment="openComments(post)"
        />
      </div>
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
import { onMounted, onBeforeUnmount, ref, watch, nextTick } from 'vue';
import FeedItem from '../components/FeedItem.vue';
import CommentsModal from '../components/CommentsModal.vue';
import { useAuthStore } from '../stores/auth';
import { useFeedStore } from '../stores/feed';
import { usePlayerStore } from '../stores/player';
import { supabase, supabaseConfigured } from '../lib/supabase';
import type { Post } from '../stores/feed';
import { useRoute, useRouter } from 'vue-router';

const auth = useAuthStore();
const feed = useFeedStore();
const player = usePlayerStore();
const route = useRoute();
const router = useRouter();

const feedContainer = ref<HTMLElement | null>(null);
const observer = ref<IntersectionObserver | null>(null);
const commentsOpen = ref(false);
const comments = ref<
  {
    id: string;
    text: string;
    created_at: string;
    profiles?: { display_name: string | null; avatar_url: string | null } | null;
  }[]
>([]);
const activePost = ref<Post | null>(null);

const likedPostIds = () => feed.likedPostIds;

const trackFor = (post: Post) => {
  if (post.track_id) {
    return feed.trackCache.get(post.track_id);
  }
  return undefined;
};

const loadTracks = async (posts: Post[]) => {
  for (const post of posts) {
    const trackId = post.track_id;
    if (trackId) {
      await feed.fetchTrack(trackId);
    }
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
      if (top?.target) {
        const id = (top.target as HTMLElement).dataset.postId;
        if (!id) return;
        feed.activePostId = id;
        const post = feed.posts.find((item) => item.id === id) ?? null;
        if (post && post !== activePost.value) {
          activePost.value = post;
          playPost(post);
        }
      }
    },
    { threshold: [0.5, 0.85] },
  );
  Array.from(feedContainer.value.children).forEach((child) => {
    const element = child as HTMLElement;
    observer.value?.observe(element);
  });
};

const playPost = async (post: Post) => {
  if (!player.audioUnlocked) return;
  const trackId = post.track_id;
  if (!trackId) return;
  try {
    const track = await feed.fetchTrack(trackId);
    const startMs = post.start_ms ?? undefined;
    const played = await player.playTrack(track, startMs);
    if (!played) throw new Error('Playback failed');
  } catch (error) {
    console.warn('Skipping unplayable track', error);
    const currentIndex = feed.posts.findIndex((item) => item.id === post.id);
    const nextPost = feed.posts[currentIndex + 1];
    if (nextPost) {
      activePost.value = nextPost;
      playPost(nextPost);
    }
  }
};

const requireProfile = async () => {
  if (!auth.userId) {
    await router.push({ path: '/auth', query: { next: route.fullPath } });
    return false;
  }
  if (auth.profileComplete) return true;
  await router.push({ path: '/profile/setup', query: { notice: 'complete', next: route.fullPath } });
  return false;
};

const toggleLike = async (post: Post) => {
  if (!(await requireProfile())) return;
  const isLiked = likedPostIds().has(post.id);
  await feed.toggleLike(post.id, isLiked);
};

const openComments = async (post: Post) => {
  if (!(await requireProfile())) return;
  commentsOpen.value = true;
  const { data } = await supabase
    .from('comments')
    .select('id, text, created_at, profiles:profiles!comments_user_id_fkey(display_name, avatar_url)')
    .eq('post_id', post.id)
    .order('created_at', { ascending: false });
  comments.value = data ?? [];
  activePost.value = post;
};

const submitComment = async (text: string) => {
  if (!activePost.value || text.trim().length === 0) return;
  if (!(await requireProfile())) return;
  await feed.addComment(activePost.value.id, text.trim());
  commentsOpen.value = false;
};

onMounted(async () => {
  await auth.init();
  if (supabaseConfigured) {
    await feed.fetchFeed();
    await loadTracks(feed.posts);
    requestAnimationFrame(setupObserver);
  }
});

watch(
  () => feed.posts.length,
  async () => {
    await nextTick();
    setupObserver();
  },
);

watch(
  () => player.audioUnlocked,
  (value) => {
    if (value && activePost.value) {
      playPost(activePost.value);
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
.sort-toggle {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}
.sort-toggle .ghost.active {
  border-color: rgba(91, 75, 255, 0.5);
  color: #ffffff;
}
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
