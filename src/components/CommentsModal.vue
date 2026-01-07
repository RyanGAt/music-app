<template>
  <div class="overlay" @click.self="$emit('close')">
    <div class="modal card">
      <header>
        <h3>Comments</h3>
        <button class="ghost" @click="$emit('close')">Close</button>
      </header>
      <div class="comments">
        <p v-if="comments.length === 0" class="secondary">No comments yet.</p>
        <div v-for="comment in comments" :key="comment.id" class="comment">
          <div class="comment-header">
            <img v-if="comment.profiles?.avatar_url" :src="comment.profiles.avatar_url" alt="" />
            <div>
              <div class="name">{{ comment.profiles?.display_name || 'SoundScroller' }}</div>
              <div class="secondary">{{ comment.text }}</div>
            </div>
          </div>
          <div class="secondary time">{{ new Date(comment.created_at).toLocaleString() }}</div>
        </div>
      </div>
      <form @submit.prevent="$emit('submit', draft)">
        <textarea v-model="draft" rows="3" maxlength="120" placeholder="Add a comment"></textarea>
        <div class="actions">
          <span class="secondary">{{ draft.length }}/120</span>
          <button class="primary" type="submit">Post</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';

defineProps<{
  comments: {
    id: string;
    text: string;
    created_at: string;
    profiles?: { display_name: string | null; avatar_url: string | null } | null;
  }[];
}>();

defineEmits(['close', 'submit']);

const draft = ref('');

watch(
  () => draft.value,
  (value) => {
    if (value.length > 120) draft.value = value.slice(0, 120);
  },
);
</script>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: grid;
  place-items: center;
  padding: 16px;
  z-index: 20;
}
.modal {
  width: 100%;
  max-width: 520px;
  display: grid;
  gap: 16px;
}
header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.comments {
  display: grid;
  gap: 12px;
  max-height: 40vh;
  overflow-y: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
}
.comments::-webkit-scrollbar {
  width: 0;
  height: 0;
}
.comment {
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  padding-bottom: 8px;
  display: grid;
  gap: 6px;
}
.comment-header {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 10px;
  align-items: start;
}
.comment-header img {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  object-fit: cover;
  border: 1px solid rgba(255, 255, 255, 0.12);
}
.name {
  font-weight: 600;
  font-size: 0.85rem;
}
.time {
  font-size: 0.7rem;
}
form {
  display: grid;
  gap: 12px;
}
.actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
textarea {
  resize: none;
}
</style>
