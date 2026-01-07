<template>
  <article class="feed-item card" :class="{ active: isActive }">
    <div class="mood">“{{ post.text || '...' }}”</div>
    <div class="track" @click="expanded = !expanded">
      <div class="secondary">
        {{ track?.title || 'Loading track…' }} — {{ track?.artist || 'Local catalog' }}
      </div>
      <div v-if="expanded" class="expanded">
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
import type { Track } from '../lib/musicProvider';

defineProps<{ post: Post; track?: Track; isActive: boolean; liked: boolean }>();

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
