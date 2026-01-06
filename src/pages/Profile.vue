<template>
  <section class="stack">
    <div v-if="profile" class="card profile">
      <img v-if="profile.avatar_url" :src="profile.avatar_url" alt="" />
      <div>
        <h2>{{ profile.display_name || 'SoundScroller' }}</h2>
        <p class="secondary">@{{ profile.spotify_user_id }}</p>
      </div>
    </div>

    <div v-if="posts.length === 0" class="card">No posts yet.</div>
    <div class="stack">
      <div v-for="post in posts" :key="post.id" class="card">
        <div class="mood">“{{ post.text || '...' }}”</div>
        <div class="secondary">{{ post.type === 'repost' ? 'Repost' : 'Moment' }}</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { supabase } from '../lib/supabase';

const route = useRoute();
const profile = ref<{ display_name: string | null; spotify_user_id: string | null; avatar_url: string | null } | null>(
  null,
);
const posts = ref<{ id: string; text: string | null; type: string }[]>([]);

onMounted(async () => {
  const userId = route.params.id as string;
  const { data: profileData } = await supabase
    .from('profiles')
    .select('display_name, spotify_user_id, avatar_url')
    .eq('id', userId)
    .single();
  profile.value = profileData;

  const { data: postData } = await supabase
    .from('posts')
    .select('id, text, type')
    .eq('user_id', userId)
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
</style>
