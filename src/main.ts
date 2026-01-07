import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { createRouter, createWebHistory } from 'vue-router';
import App from './App.vue';
import Feed from './pages/Feed.vue';
import Random from './pages/Random.vue';
import Activity from './pages/Activity.vue';
import Profile from './pages/Profile.vue';
import './style.css';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/feed' },
    { path: '/feed', component: Feed },
    { path: '/random', component: Random },
    { path: '/activity', component: Activity },
    { path: '/u/:id', component: Profile, props: true },
  ],
});

const app = createApp(App);
app.use(createPinia());
app.use(router);
app.mount('#app');
