<template>
  <article class="feed-item card" :class="{ active: isActive }">
    <div class="mood">“{{ post.text || 'Auto moment' }}”</div>
    <div class="track" @click="expanded = !expanded">
      <img v-if="track?.artwork_url" class="art" :src="track.artwork_url" alt="" />
      <div class="track-info">
        <div class="primary">
          {{ track?.title || 'Loading track…' }} <span class="source">Audius</span>
        </div>
        <div class="secondary">{{ track?.artist || 'Unknown artist' }}</div>
        <div class="secondary" v-if="momentLabel">Moment: {{ momentLabel }}</div>
      </div>
      <div v-if="expanded" class="expanded">
        <div class="secondary">Tap to collapse</div>
        <a v-if="track?.permalink_url" :href="track.permalink_url" target="_blank" rel="noreferrer">
          Open on Audius
        </a>
      </div>
    </div>
    <div class="actions">
      <button class="ghost" @click="$emit('like')">
        {{ liked ? 'Unlike' : 'Like' }} ({{ post.likeCount ?? 0 }})
      </button>
      <button class="ghost" @click="$emit('comment')">
        Comments ({{ post.commentCount ?? 0 }})
      </button>
    </div>
    <div class="meta">
      <span class="secondary">{{ post.likeCount ?? 0 }} likes</span>
      <span class="secondary">{{ post.commentCount ?? 0 }} comments</span>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import type { Post } from '../stores/feed';
import type { Track } from '../lib/musicProvider';

const props = defineProps<{ post: Post; track?: Track; isActive: boolean; liked: boolean }>();

defineEmits(['like', 'comment']);

const expanded = ref(false);

const momentLabel = computed(() => {
  const startMs = props.post.start_ms;
  if (startMs === null || startMs === undefined) return '';
  const totalSeconds = Math.floor(startMs / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = String(totalSeconds % 60).padStart(2, '0');
  return `${minutes}:${seconds}`;
});
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
  display: grid;
  gap: 12px;
  justify-items: center;
}
.track-info {
  display: grid;
  gap: 4px;
  justify-items: center;
}
.art {
  width: 72px;
  height: 72px;
  border-radius: 12px;
  object-fit: cover;
  border: 1px solid rgba(255, 255, 255, 0.12);
}
.primary {
  font-weight: 600;
}
.source {
  font-size: 0.75rem;
  margin-left: 6px;
  padding: 2px 6px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.08);
}
.expanded {
  margin-top: 8px;
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
