<template>
  <div
    v-if="show"
    ref="containerRef"
    class="fixed z-50 w-56 rounded-2xl border border-n-weak bg-n-surface-1 py-2 shadow-lg"
    :style="{ top: `${y}px`, left: `${x}px` }"
  >
    <div class="mb-1 border-b border-n-weak px-3 py-2">
      <p class="truncate text-xs font-medium text-n-slate-12">
        #{{ item.id }} - {{ item.meta?.sender?.name }}
      </p>
    </div>

    <button 
      @click="handleAction('edit')"
      class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-blue-11"
    >
      <i class="i-lucide-pencil text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.EDIT') }}
    </button>

    <button 
      @click="handleAction('view_contact')"
      class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-blue-11"
    >
      <i class="i-lucide-user text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.VIEW_CONTACT') }}
    </button>

    <button 
      @click="handleAction('open_conversation')"
      class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-blue-11"
    >
      <i class="i-lucide-message-circle text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.OPEN_CONVERSATION') }}
    </button>

    <div v-if="isAdmin" class="my-1 border-t border-n-weak"></div>

    <button 
      v-if="isAdmin"
      @click="handleAction('delete')"
      class="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-n-ruby-11 transition-colors hover:bg-n-ruby-3"
    >
      <i class="i-lucide-trash-2 text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.DELETE') }}
    </button>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';

const props = defineProps({
  show: Boolean,
  x: Number,
  y: Number,
  item: Object,
});

const emit = defineEmits(['close', 'action']);
const { t } = useI18n();
const { isAdmin } = useAdmin();
const containerRef = ref(null);

const close = () => emit('close');

const handleAction = (action) => {
  emit('action', { action, item: props.item });
  close();
};

// Simple click outside directive logic
const handleClickOutside = event => {
  if (props.show && containerRef.value && !containerRef.value.contains(event.target)) {
    close();
  }
};

onMounted(() => {
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside);
});
</script>