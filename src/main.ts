import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';
import Feed from './pages/Feed.vue';
import Random from './pages/Random.vue';
import Activity from './pages/Activity.vue';
import Profile from './pages/Profile.vue';
import ProfileSetup from './pages/ProfileSetup.vue';
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
    { path: '/activity', component: Activity },
    { path: '/profile', component: ProfileSetup },
    { path: '/u/:id', component: Profile, props: true },
  ],
});

router.beforeEach(async (to) => {
  if (!supabaseConfigured) return true;
  const auth = useAuthStore(pinia);
  if (!auth.ready) {
    await auth.init();
  }
  if (to.path === '/profile') return true;
  if (auth.userId && !auth.profileComplete) {
    return { path: '/profile', query: { notice: 'complete', next: to.fullPath } };
  }
  return true;
});

const app = createApp(App);
app.use(pinia);
app.use(router);
app.mount('#app');
