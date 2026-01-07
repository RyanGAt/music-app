<template>
  <section class="stack">
    <div v-if="auth.error" class="card error">{{ auth.error }}</div>

    <div class="card stack">
      <label class="secondary">Search mock tracks</label>
      <input v-model="query" @input="search" placeholder="Search tracks" />
      <div class="results">
        <button v-for="track in results" :key="track.id" class="result" @click="selectTrack(track)">
          <div>
            <div>{{ track.title }}</div>
            <div class="secondary">{{ track.artist }}</div>
          </div>
        </button>
      </div>
    </div>

    <div v-if="selected" class="card stack">
      <h3>{{ selected.title }}</h3>
      <div class="secondary">{{ selected.artist }}</div>
      <label class="secondary">Start time (mm:ss)</label>
      <input v-model="startTime" placeholder="00:30" />
      <label class="secondary">Mood text (max 120)</label>
      <textarea v-model="text" rows="3" maxlength="120"></textarea>
      <div class="actions">
        <span class="secondary">{{ text.length }}/120</span>
        <button class="primary" @click="createPost">Post</button>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuthStore } from '../stores/auth';
import { mockMusicProvider } from '../lib/mockMusicProvider';
import type { Track } from '../lib/musicProvider';
import { supabase } from '../lib/supabase';

const auth = useAuthStore();

const query = ref('');
const results = ref<Track[]>([]);
const selected = ref<Track | null>(null);
const startTime = ref('');
const text = ref('');

const search = async () => {
  if (query.value.length < 2) {
    results.value = [];
    return;
  }
  results.value = await mockMusicProvider.searchTracks(query.value);
};

const selectTrack = (track: Track) => {
  selected.value = track;
};

const parseStartMs = () => {
  if (!startTime.value) return null;
  const parts = startTime.value.split(':').map(Number);
  if (parts.length !== 2 || parts.some((p) => Number.isNaN(p))) return null;
  return (parts[0] * 60 + parts[1]) * 1000;
};

const createPost = async () => {
  if (!selected.value) return;
  await supabase.from('posts').insert({
    user_id: auth.userId,
    type: 'song_moment',
    track_id: selected.value.id,
    start_ms: parseStartMs(),
    text: text.value.slice(0, 120),
  });
  selected.value = null;
  query.value = '';
  results.value = [];
  startTime.value = '';
  text.value = '';
  alert('Posted!');
};

onMounted(async () => {
  await auth.init();
});
</script>

<style scoped>
.results {
  display: grid;
  gap: 8px;
}
.result {
  display: flex;
  gap: 12px;
  align-items: center;
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.08);
  padding: 8px;
  border-radius: 12px;
  color: inherit;
  cursor: pointer;
}
.actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
textarea {
  resize: none;
}
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
