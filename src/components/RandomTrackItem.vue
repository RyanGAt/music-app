<template>
  <article class="feed-item card" :class="{ active: isActive }">
    <div class="mood">Random pick</div>
    <div class="track" @click="expanded = !expanded">
      <img v-if="track.artwork_url" class="art" :src="track.artwork_url" alt="" />
      <div class="track-info">
        <div class="primary">
          {{ track.title }} <span class="source">Audius</span>
        </div>
        <div class="secondary">{{ track.artist }}</div>
      </div>
      <div v-if="expanded" class="expanded">
        <div class="secondary">Tap to collapse</div>
        <a v-if="track.permalink_url" :href="track.permalink_url" target="_blank" rel="noreferrer">
          Open on Audius
        </a>
      </div>
    </div>
    <div class="meta">
      <span class="secondary">{{ likeCount }} likes</span>
      <span class="secondary">{{ commentCount }} comments</span>
    </div>
  </article>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { Track } from '../lib/musicProvider';

defineProps<{ track: Track; likeCount: number; commentCount: number; isActive: boolean }>();

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
.meta {
  display: flex;
  justify-content: center;
  gap: 16px;
}
</style>
