<template>
  <div class="app-shell">
    <header class="app-header">
      <div class="brand">SoundScroll</div>
      <nav class="nav">
        <RouterLink to="/feed">Feed</RouterLink>
        <RouterLink to="/random">Random</RouterLink>
        <RouterLink to="/activity">Activity</RouterLink>
      </nav>
    </header>
    <main class="app-main">
      <RouterView />
    </main>
  </div>
</template>

<script setup lang="ts"></script>

<style scoped>
.app-shell {
  min-height: 100vh;
  background: #0b0b0f;
  color: #f2f2f7;
}
.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  position: sticky;
  top: 0;
  z-index: 10;
  background: rgba(11, 11, 15, 0.9);
  backdrop-filter: blur(12px);
}
.brand {
  font-weight: 600;
  letter-spacing: 0.04em;
}
.nav {
  display: flex;
  gap: 12px;
}
.nav a {
  color: #c7c7d2;
  text-decoration: none;
  font-size: 0.9rem;
}
.nav a.router-link-active {
  color: #ffffff;
}
.app-main {
  max-width: 720px;
  margin: 0 auto;
  padding: 0 16px 80px;
}
</style>
