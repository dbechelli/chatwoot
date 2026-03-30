<script setup>
import { onMounted } from 'vue';
import { useStore } from 'vuex';

const store = useStore();

onMounted(() => {
  store.dispatch('kanban/fetch');
});
</script>

<template>
  <div class="flex h-full w-full min-h-0 min-w-0">
    <section class="flex h-full w-full min-w-0 flex-1 overflow-hidden bg-n-surface-1">
      <router-view />
    </section>
  </div>
</template>