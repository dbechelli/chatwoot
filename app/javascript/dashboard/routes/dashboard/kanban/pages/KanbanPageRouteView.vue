<script setup>
import { onMounted } from 'vue';
import { useStore } from 'vuex';

const store = useStore();

onMounted(() => {
  store.dispatch('kanban/fetch');
});
</script>

<template>
  <div class="flex h-full min-h-0 flex-col bg-n-slate-2">
    <section class="min-w-0 flex-1 overflow-hidden">
      <router-view />
    </section>
  </div>
</template>