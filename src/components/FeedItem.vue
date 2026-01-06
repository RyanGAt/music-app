<template>
  <article class="feed-item card" :class="{ active: isActive }">
    <div class="mood">“{{ post.text || '...' }}”</div>
    <div class="track" @click="expanded = !expanded">
      <div class="secondary">
        {{ track?.name || 'Loading track…' }} —
        {{ track?.artists?.map((artist) => artist.name).join(', ') || 'Spotify' }}
      </div>
      <div v-if="expanded" class="expanded">
        <img v-if="track?.album?.images?.[0]?.url" :src="track.album.images[0].url" alt="Album art" />
        <div class="secondary">Tap to collapse</div>
      </div>
    </div>
    <div class="actions">
      <button class="ghost" @click="$emit('like')">{{ liked ? 'Unlike' : 'Like' }}</button>
      <button class="ghost" @click="$emit('repost')">Repost</button>
      <button class="ghost" @click="$emit('comment')">Comments ({{ post.commentCount ?? 0 }})</button>
    </div>
    <div class="meta">
      <span class="secondary">{{ post.likeCount ?? 0 }} likes</span>
      <span class="secondary" v-if="post.type === 'repost'">Repost</span>
    </div>
  </article>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { Post } from '../stores/feed';
import type { SpotifyTrack } from '../lib/spotify';

defineProps<{ post: Post; track?: SpotifyTrack; isActive: boolean; liked: boolean }>();

defineEmits(['like', 'repost', 'comment']);

const expanded = ref(false);
</script>

<style scoped>
.feed-item {
  min-height: 70vh;
  display: grid;
  gap: 12px;
  align-content: center;
}
.feed-item.active {
  border-color: rgba(91, 75, 255, 0.6);
}
.mood {
  font-size: 1.4rem;
  font-weight: 500;
  text-align: center;
}
.track {
  text-align: center;
  cursor: pointer;
}
.expanded {
  margin-top: 12px;
  display: grid;
  justify-items: center;
  gap: 8px;
}
.expanded img {
  width: 140px;
  height: 140px;
  border-radius: 12px;
}
.actions {
  display: flex;
  justify-content: center;
  gap: 12px;
  flex-wrap: wrap;
}
.meta {
  display: flex;
  justify-content: center;
  gap: 16px;
}
</style>
