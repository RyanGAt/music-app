<template>
  <section class="stack">
    <div v-if="!supabaseConfigured" class="card error">
      Missing Supabase env. Add <code>VITE_SUPABASE_URL</code> and
      <code>VITE_SUPABASE_ANON_KEY</code> to <code>.env</code> and restart the dev server.
    </div>
    <div v-else-if="profile" class="card profile">
      <img v-if="profile.avatar_url" :src="profile.avatar_url" alt="" />
      <div>
        <h2>{{ profile.display_name || 'SoundScroller' }}</h2>
        <p class="secondary">{{ shortId }}</p>
      </div>
    </div>

    <div v-if="posts.length === 0" class="card">No posts yet.</div>
    <div class="stack">
      <div v-for="post in posts" :key="post.id" class="card">
        <div class="mood">“{{ post.text || 'Auto moment' }}”</div>
        <div class="secondary">Auto moment</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { supabase, supabaseConfigured } from '../lib/supabase';

const route = useRoute();
const profile = ref<{ display_name: string | null; avatar_url: string | null } | null>(null);
const posts = ref<{ id: string; text: string | null; type: string }[]>([]);

const shortId = computed(() => {
  const id = route.params.id as string;
  return `id: ${id.slice(0, 8)}`;
});

onMounted(async () => {
  if (!supabaseConfigured) return;
  const userId = route.params.id as string;
  const { data: profileData } = await supabase
    .from('profiles')
    .select('display_name, avatar_url')
    .eq('id', userId)
    .single();
  profile.value = profileData;

  const { data: postData } = await supabase
    .from('posts')
    .select('id, text, type')
    .eq('user_id', userId)
    .eq('type', 'auto_moment')
    .order('created_at', { ascending: false })
    .limit(12);
  posts.value = postData ?? [];
});
</script>

<style scoped>
.profile {
  display: flex;
  gap: 16px;
  align-items: center;
}
.profile img {
  width: 64px;
  height: 64px;
  border-radius: 50%;
}
.mood {
  font-size: 1.1rem;
}
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
