<template>
  <div 
    v-if="show"
    class="fixed z-50 bg-white rounded-lg shadow-xl border border-slate-200 py-1 w-48"
    :style="{ top: `${y}px`, left: `${x}px` }"
    v-click-outside="close"
  >
    <div class="px-3 py-2 border-b border-slate-100 mb-1">
      <p class="text-xs font-bold text-slate-800 truncate">
        #{{ item.id }} - {{ item.meta?.sender?.name }}
      </p>
    </div>

    <button 
      @click="handleAction('edit')"
      class="w-full text-left px-3 py-2 text-sm text-slate-600 hover:bg-slate-50 hover:text-blue-600 flex items-center gap-2"
    >
      <i class="i-lucide-pencil text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.EDIT') }}
    </button>

    <button 
      @click="handleAction('view_contact')"
      class="w-full text-left px-3 py-2 text-sm text-slate-600 hover:bg-slate-50 hover:text-blue-600 flex items-center gap-2"
    >
      <i class="i-lucide-user text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.VIEW_CONTACT') }}
    </button>

    <button 
      @click="handleAction('open_conversation')"
      class="w-full text-left px-3 py-2 text-sm text-slate-600 hover:bg-slate-50 hover:text-blue-600 flex items-center gap-2"
    >
      <i class="i-lucide-message-circle text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.OPEN_CONVERSATION') }}
    </button>

    <div v-if="isAdmin" class="border-t border-slate-100 my-1"></div>

    <button 
      v-if="isAdmin"
      @click="handleAction('delete')"
      class="w-full text-left px-3 py-2 text-sm text-red-600 hover:bg-red-50 flex items-center gap-2"
    >
      <i class="i-lucide-trash-2 text-xs" />
      {{ t('KANBAN.CONTEXT_MENU.DELETE') }}
    </button>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted } from 'vue';
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

const close = () => emit('close');

const handleAction = (action) => {
  emit('action', { action, item: props.item });
  close();
};

// Simple click outside directive logic
const handleClickOutside = (event) => {
  if (props.show && !event.target.closest('.fixed.z-50')) {
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