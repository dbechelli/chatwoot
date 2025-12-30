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
    // Conversa foi movida para esta coluna
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
  <div class="flex flex-col rounded-lg border border-n-slate-6 bg-n-slate-2">
    <!-- Cabeçalho da coluna -->
    <div
      class="flex flex-col gap-2 border-b border-n-slate-6 p-4"
      :class="{ 'bg-red-50': isOverLimit }"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <div
            class="h-3 w-3 rounded-full"
            :style="{ backgroundColor: color }"
          />
          <h3 class="text-sm font-semibold text-n-slate-12">
            {{ title }}
          </h3>
        </div>
        <div
          class="flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium"
          :class="
            isOverLimit
              ? 'bg-red-100 text-red-800'
              : 'bg-n-slate-4 text-n-slate-11'
          "
        >
          <span>{{ conversations.length }}</span>
          <span v-if="wipLimit">/ {{ wipLimit }}</span>
        </div>
      </div>

      <!-- Total value -->
      <div v-if="totalValue > 0" class="flex items-center gap-1">
        <i class="i-lucide-trending-up text-sm text-green-600" />
        <span class="text-sm font-semibold text-green-700">
          {{ formatCurrency(totalValue) }}
        </span>
      </div>

      <!-- WIP Warning -->
      <div
        v-if="isOverLimit"
        class="flex items-center gap-2 rounded bg-red-50 p-2 text-xs text-red-800"
      >
        <i class="i-lucide-alert-triangle" />
        <span>{{ t('KANBAN.WIP_LIMIT_EXCEEDED') }}</span>
      </div>
    </div>

    <!-- Lista de cards -->
    <Draggable
      v-model="localConversations"
      group="kanban-conversations"
      item-key="id"
      class="flex flex-1 flex-col gap-3 overflow-y-auto p-3 min-h-[200px] max-h-[calc(100vh-300px)]"
      ghost-class="opacity-50"
      drag-class="rotate-2"
      @change="handleChange"
    >
      <template #item="{ element }">
        <div @click="handleCardClick(element)">
          <KanbanCard :conversation="element" />
        </div>
      </template>
    </Draggable>

    <!-- Empty state -->
    <div
      v-if="!conversations.length"
      class="flex flex-col items-center justify-center gap-2 p-8 text-center"
    >
      <i class="i-lucide-inbox text-4xl text-n-slate-8" />
      <p class="text-sm text-n-slate-11">
        {{ t('KANBAN.EMPTY_COLUMN') }}
      </p>
    </div>
  </div>
</template>

<style scoped>
/* Scrollbar customizado */
::-webkit-scrollbar {
  width: 6px;
}

::-webkit-scrollbar-thumb {
  background: var(--color-border);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--color-border-dark);
}
</style>
