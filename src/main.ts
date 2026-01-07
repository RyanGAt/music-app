import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';
import Feed from './pages/Feed.vue';
import Random from './pages/Random.vue';
import Activity from './pages/Activity.vue';
import Profile from './pages/Profile.vue';
import ProfileSetup from './pages/ProfileSetup.vue';
import PublicProfile from './pages/PublicProfile.vue';
import Auth from './pages/Auth.vue';
import { supabaseConfigured } from './lib/supabase';
import { useAuthStore } from './stores/auth';
import './style.css';

const pinia = createPinia();

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/feed' },
    { path: '/feed', component: Feed },
    { path: '/random', component: Random },
    { path: '/activity', component: Activity, meta: { requiresAuth: true } },
    { path: '/auth', component: Auth },
    { path: '/profile', component: Profile, meta: { requiresAuth: true } },
    { path: '/profile/setup', component: ProfileSetup, meta: { requiresAuth: true } },
    { path: '/u/:id', component: PublicProfile, props: true },
  ],
});

router.beforeEach(async (to) => {
  if (!supabaseConfigured) return true;
  const auth = useAuthStore(pinia);
  if (!auth.ready) {
    await auth.init();
  }
  if (to.meta.requiresAuth && !auth.userId) {
    return { path: '/auth', query: { next: to.fullPath } };
  }
  if (auth.userId && !auth.profileComplete && to.path !== '/profile/setup' && to.path !== '/auth') {
    return { path: '/profile/setup', query: { notice: 'complete', next: to.fullPath } };
  }
  return true;
});

const app = createApp(App);
app.use(pinia);
app.use(router);
app.mount('#app');
