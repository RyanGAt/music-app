<template>
  <section class="stack">
    <div v-if="!supabaseConfigured" class="card error">
      Missing Supabase env. Add <code>VITE_SUPABASE_URL</code> and
      <code>VITE_SUPABASE_ANON_KEY</code> to <code>.env</code> and restart the dev server.
    </div>
    <div v-else class="card stack">
      <h2>Sign in</h2>
      <p class="secondary">Use your email and password to access your profile and activity.</p>
      <div v-if="auth.error" class="error-text">{{ auth.error }}</div>
      <label class="secondary" for="email">Email</label>
      <input id="email" v-model="email" type="email" placeholder="you@example.com" required />
      <label class="secondary" for="password">Password</label>
      <input id="password" v-model="password" type="password" placeholder="••••••••" required />
      <div class="actions">
        <button class="primary" :disabled="auth.loading" @click="submitSignIn">
          {{ auth.loading ? 'Signing in…' : 'Sign in' }}
        </button>
        <button class="ghost" :disabled="auth.loading" @click="submitSignUp">
          {{ auth.loading ? 'Creating…' : 'Create account' }}
        </button>
      </div>
    </div>

    <div v-if="auth.userId" class="card stack">
      <h3>Signed in</h3>
      <p class="secondary">{{ auth.email }}</p>
      <div class="actions">
        <RouterLink class="ghost" to="/profile">View profile</RouterLink>
        <RouterLink class="ghost" to="/profile/setup">Edit profile</RouterLink>
        <button class="ghost" :disabled="auth.loading" @click="handleSignOut">Sign out</button>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { supabaseConfigured } from '../lib/supabase';
import { useAuthStore } from '../stores/auth';

const auth = useAuthStore();
const router = useRouter();

const email = ref('');
const password = ref('');

const submitSignIn = async () => {
  if (!email.value || !password.value) return;
  try {
    await auth.signIn(email.value.trim(), password.value);
    await router.push('/profile');
  } catch {
    // errors are surfaced through the store
  }
};

const submitSignUp = async () => {
  if (!email.value || !password.value) return;
  try {
    await auth.signUp(email.value.trim(), password.value);
    await router.push('/profile/setup');
  } catch {
    // errors are surfaced through the store
  }
};

const handleSignOut = async () => {
  try {
    await auth.signOut();
  } catch {
    // errors are surfaced through the store
  }
};

onMounted(async () => {
  await auth.init();
  if (auth.email) {
    email.value = auth.email;
  }
});
</script>

<style scoped>
.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
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
