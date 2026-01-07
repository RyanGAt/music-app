<template>
  <section class="stack">
    <div v-if="!supabaseConfigured" class="card error">
      Missing Supabase env. Add <code>VITE_SUPABASE_URL</code> and
      <code>VITE_SUPABASE_ANON_KEY</code> to <code>.env</code> and restart the dev server.
    </div>
    <div v-else-if="auth.error" class="card error">{{ auth.error }}</div>
    <div v-else class="card stack">
      <div v-if="notice" class="notice">{{ notice }}</div>
      <h2>Profile Maker</h2>
      <p class="secondary">Pick a display name so you can like and comment.</p>
      <label class="secondary" for="display-name">Display name</label>
      <input
        id="display-name"
        v-model="displayName"
        maxlength="24"
        placeholder="SoundScroller"
        required
      />
      <div class="secondary hint">{{ displayName.trim().length }}/24</div>
      <label class="secondary" for="avatar-url">Avatar URL (optional)</label>
      <input id="avatar-url" v-model="avatarUrl" placeholder="https://..." />
      <div v-if="avatarPreview" class="avatar-preview">
        <img :src="avatarPreview" alt="" />
      </div>
      <div v-if="formError" class="error-text">{{ formError }}</div>
      <button class="primary" :disabled="saving" @click="saveProfile">
        {{ saving ? 'Saving…' : 'Save profile' }}
      </button>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase, supabaseConfigured } from '../lib/supabase';
import { useAuthStore } from '../stores/auth';

const auth = useAuthStore();
const route = useRoute();
const router = useRouter();

const displayName = ref('');
const avatarUrl = ref('');
const formError = ref('');
const saving = ref(false);

const avatarPreview = computed(() => avatarUrl.value.trim());

const notice = computed(() => {
  if (route.query.notice === 'complete') {
    return 'Please finish your profile before you can like or comment.';
  }
  return '';
});

const validate = () => {
  const name = displayName.value.trim();
  if (name.length < 2 || name.length > 24) {
    formError.value = 'Display name must be between 2 and 24 characters.';
    return null;
  }
  formError.value = '';
  return name;
};

const saveProfile = async () => {
  if (!supabaseConfigured) return;
  const name = validate();
  if (!name) return;
  if (!auth.userId) {
    formError.value = 'Unable to load your account. Please refresh.';
    return;
  }
  saving.value = true;
  try {
    const avatar = avatarUrl.value.trim();
    await supabase.from('profiles').upsert({
      id: auth.userId,
      display_name: name,
      avatar_url: avatar.length > 0 ? avatar : null,
    });
    auth.profile = { id: auth.userId, display_name: name, avatar_url: avatar.length > 0 ? avatar : null };
    auth.profileComplete = true;
    const next = typeof route.query.next === 'string' ? route.query.next : '/feed';
    await router.replace(next);
  } catch (error) {
    formError.value = error instanceof Error ? error.message : 'Failed to save profile.';
  } finally {
    saving.value = false;
  }
};

onMounted(async () => {
  await auth.init();
  if (auth.profile) {
    displayName.value = auth.profile.display_name ?? '';
    avatarUrl.value = auth.profile.avatar_url ?? '';
  }
});
</script>

<style scoped>
.notice {
  background: rgba(91, 75, 255, 0.16);
  border: 1px solid rgba(91, 75, 255, 0.3);
  color: #d5d0ff;
  padding: 10px 12px;
  border-radius: 12px;
}
.hint {
  text-align: right;
  font-size: 0.75rem;
}
.avatar-preview {
  display: flex;
  justify-content: center;
}
.avatar-preview img {
  width: 96px;
  height: 96px;
  border-radius: 50%;
  object-fit: cover;
  border: 1px solid rgba(255, 255, 255, 0.12);
}
.error-text {
  color: #ff758f;
  font-size: 0.85rem;
}
.error {
  background: rgba(255, 0, 80, 0.1);
  border-color: rgba(255, 0, 80, 0.3);
}
</style>
