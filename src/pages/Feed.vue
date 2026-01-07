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

    <div v-if="supabaseConfigured" ref="feedContainer" class="feed-list">
      <div v-for="post in feed.posts" :key="post.id" :data-post-id="post.id">
        <FeedItem
          :post="post"
          :track="trackFor(post)"
          :is-active="feed.activePostId === post.id"
          :liked="likedPostIds().has(post.id)"
          @like="toggleLike(post)"
          @repost="openRepost(post)"
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

const auth = useAuthStore();
const feed = useFeedStore();
const player = usePlayerStore();

const feedContainer = ref<HTMLElement | null>(null);
const observer = ref<IntersectionObserver | null>(null);
const commentsOpen = ref(false);
const comments = ref<{ id: string; text: string; created_at: string }[]>([]);
const activePost = ref<Post | null>(null);

const likedPostIds = () => feed.likedPostIds;

const trackFor = (post: Post) => {
  if (post.type === 'repost' && post.original?.track_id) {
    return feed.trackCache.get(post.original.track_id);
  }
  if (post.track_id) {
    return feed.trackCache.get(post.track_id);
  }
  return undefined;
};

const loadTracks = async (posts: Post[]) => {
  for (const post of posts) {
    const trackId = post.type === 'repost' ? post.original?.track_id : post.track_id;
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
  const trackId = post.type === 'repost' ? post.original?.track_id : post.track_id;
  if (!trackId) return;
  const track = await feed.fetchTrack(trackId);
  await player.playTrack(track, post.type === 'repost' ? post.original?.start_ms ?? undefined : post.start_ms ?? undefined);
};

const toggleLike = async (post: Post) => {
  const isLiked = likedPostIds().has(post.id);
  await feed.toggleLike(post.id, isLiked);
};

const openRepost = async (post: Post) => {
  const text = prompt('Add a caption (optional)') || null;
  await feed.repost(post.id, text);
};

const openComments = async (post: Post) => {
  commentsOpen.value = true;
  const { data } = await supabase
    .from('comments')
    .select('id, text, created_at')
    .eq('post_id', post.id)
    .order('created_at', { ascending: false });
  comments.value = data ?? [];
  activePost.value = post;
};

const submitComment = async (text: string) => {
  if (!activePost.value || text.trim().length === 0) return;
  await feed.addComment(activePost.value.id, text.trim());
  commentsOpen.value = false;
};

onMounted(async () => {
  await auth.init();
  if (supabaseConfigured && auth.userId) {
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
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
