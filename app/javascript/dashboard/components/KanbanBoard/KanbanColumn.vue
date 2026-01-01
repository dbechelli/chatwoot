<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  stage: { type: String, required: true },
  title: { type: String, required: true },
  color: { type: String, default: '#3b82f6' },
  conversations: { type: Array, required: true },
  wipLimit: { type: Number, default: null },
  visibleAttributes: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:conversations', 'stageChange', 'cardClick']);

const { t } = useI18n();

const localConversations = computed({
  get: () => props.conversations,
  set: value => emit('update:conversations', value),
});

const isOverLimit = computed(() => {
  return props.wipLimit && props.conversations.length > props.wipLimit;
});

const totalValue = computed(() => {
  return props.conversations.reduce((sum, conv) => {
    return sum + (conv.custom_attributes?.deal_value || 0);
  }, 0);
});

const formatCurrency = value => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    minimumFractionDigits: 0,
  }).format(value);
};

const handleChange = evt => {
  if (evt.added) {
    emit('stageChange', {
      conversationId: evt.added.element.id,
      newStage: props.stage,
      conversation: evt.added.element,
    });
  }
};

const handleCardClick = conversation => {
  emit('cardClick', conversation);
};
</script>

<template>
  <div 
    class="flex flex-col rounded-xl border border-slate-200 bg-slate-50/50 shadow-sm overflow-hidden h-full transition-colors"
    :class="{ 'border-red-300 bg-red-50/30': isOverLimit }"
  >
    <div class="flex flex-col gap-2 p-4 bg-white border-b border-slate-200">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2.5 overflow-hidden">
          <div
            class="h-3 w-3 rounded-full flex-shrink-0"
            :style="{ backgroundColor: color, boxShadow: `0 0 8px ${color}60` }"
          />
          <h3 class="text-sm font-bold text-slate-800 truncate uppercase tracking-wide">
            {{ title }}
          </h3>
        </div>
        
        <div
          class="flex items-center gap-1 rounded-md px-2 py-0.5 text-[11px] font-bold shadow-sm border"
          :class="
            isOverLimit
              ? 'bg-red-500 text-white border-red-600'
              : 'bg-slate-100 text-slate-600 border-slate-200'
          "
        >
          <span>{{ conversations.length }}</span>
          <span v-if="wipLimit" class="opacity-70">/ {{ wipLimit }}</span>
        </div>
      </div>

      <div v-if="totalValue > 0" class="flex items-center gap-1.5 mt-1">
        <div class="flex items-center gap-1 px-2 py-0.5 bg-emerald-50 rounded-md border border-emerald-100">
          <i class="i-lucide-trending-up text-xs text-emerald-600" />
          <span class="text-xs font-bold text-emerald-700">
            {{ formatCurrency(totalValue) }}
          </span>
        </div>
      </div>

      <Transition name="fade">
        <div
          v-if="isOverLimit"
          class="flex items-center gap-2 rounded-lg bg-red-100 p-2 text-[11px] font-bold text-red-700 mt-1 animate-pulse"
        >
          <i class="i-lucide-alert-triangle text-sm" />
          <span>{{ t('KANBAN.WIP_LIMIT_EXCEEDED') }}</span>
        </div>
      </Transition>
    </div>

    <Draggable
      v-model="localConversations"
      group="kanban-conversations"
      item-key="id"
      class="flex-1 flex flex-col gap-3 overflow-y-auto p-3 min-h-[150px] custom-scrollbar-inside"
      ghost-class="ghost-card"
      drag-class="dragging-card"
      @change="handleChange"
    >
      <template #item="{ element }">
        <div @click="handleCardClick(element)" class="transform transition-transform active:scale-95">
          <KanbanCard 
            :conversation="element" 
            :visible-attributes="visibleAttributes"
          />
        </div>
      </template>

      <template #footer v-if="!conversations.length">
        <div class="flex flex-col items-center justify-center gap-3 py-10 opacity-40 grayscale">
          <div class="p-4 rounded-full bg-slate-200">
            <i class="i-lucide-inbox text-3xl text-slate-500" />
          </div>
          <p class="text-xs font-bold text-slate-500 text-center px-4 uppercase tracking-tighter">
            {{ t('KANBAN.EMPTY_COLUMN') }}
          </p>
        </div>
      </template>
    </Draggable>
  </div>
</template>

<style scoped>
/* Estilo para o card fantasma (onde ele vai cair) */
.ghost-card {
  opacity: 0.3;
  background: #cbd5e1 !important;
  border: 2px dashed #94a3b8 !important;
  border-radius: 12px;
}

/* Estilo para o card sendo arrastado */
.dragging-card {
  transform: rotate(3deg);
  cursor: grabbing !important;
}

/* Scrollbar interno da coluna */
.custom-scrollbar-inside::-webkit-scrollbar {
  width: 5px;
}

.custom-scrollbar-inside::-webkit-scrollbar-track {
  background: transparent;
}

.custom-scrollbar-inside::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}

.custom-scrollbar-inside::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

/* Animação simples */
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>
