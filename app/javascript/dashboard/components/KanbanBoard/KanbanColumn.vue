<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  stage: { type: String, required: true },
  title: { type: String, required: true },
  color: { type: String, default: '#3b82f6' },
  conversations: { type: Array, required: true },
  wipLimit: { type: Number, default: null },
  visibleAttributes: { type: Array, default: () => [] },
  canManageBoard: { type: Boolean, default: false },
});

const emit = defineEmits([
  'update:conversations',
  'stageChange',
  'cardClick',
  'cardContextmenu',
  'editStage',
  'duplicateStage',
  'addStageAfter',
  'addItem',
]);

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

const hexToRgb = hex => {
  if (!hex) return null;

  const normalized = hex.replace('#', '');
  const value = normalized.length === 3
    ? normalized.split('').map(char => `${char}${char}`).join('')
    : normalized;

  if (value.length !== 6) return null;

  const int = Number.parseInt(value, 16);

  return {
    r: (int >> 16) & 255,
    g: (int >> 8) & 255,
    b: int & 255,
  };
};

const headerStyle = computed(() => {
  const rgb = hexToRgb(props.color);

  if (!rgb) {
    return {};
  }

  return {
    background: `linear-gradient(180deg, rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.16) 0%, rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.07) 100%)`,
    borderTop: `3px solid ${props.color}`,
  };
});

const countStyle = computed(() => {
  const rgb = hexToRgb(props.color);

  if (!rgb) {
    return {};
  }

  return {
    backgroundColor: `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.14)`,
    color: props.color,
  };
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
    class="flex h-full flex-col overflow-hidden rounded-2xl border border-n-weak bg-n-surface-1 transition-colors"
    :class="{ 'border-n-ruby-7 bg-n-ruby-3/20': isOverLimit }"
  >
    <div class="flex flex-col gap-3 border-b border-n-weak px-4 py-4" :style="headerStyle">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2.5 overflow-hidden">
          <h3 class="truncate text-sm font-medium uppercase tracking-wide text-n-slate-12">
            {{ title }}
          </h3>
        </div>

        <div class="flex items-center gap-1.5">
          <div
            class="flex items-center gap-1 rounded-lg border border-transparent px-2 py-0.5 text-[11px] font-medium"
            :class="isOverLimit ? 'border-n-ruby-7/40 bg-n-ruby-3 text-n-ruby-11' : ''"
            :style="!isOverLimit ? countStyle : {}"
          >
            <span>{{ conversations.length }}</span>
            <span v-if="wipLimit" class="opacity-70">/ {{ wipLimit }}</span>
          </div>

          <template v-if="canManageBoard">
            <button
              class="inline-flex h-7 w-7 items-center justify-center rounded-lg text-n-slate-10 transition-colors hover:bg-n-surface-1/80 hover:text-n-slate-12"
              :title="t('KANBAN.COLUMN_ACTIONS.EDIT_STAGE')"
              @click.stop="emit('editStage', stage)"
            >
              <i class="i-lucide-settings-2 text-sm" />
            </button>
            <button
              class="inline-flex h-7 w-7 items-center justify-center rounded-lg text-n-slate-10 transition-colors hover:bg-n-surface-1/80 hover:text-n-slate-12"
              :title="t('KANBAN.COLUMN_ACTIONS.DUPLICATE_STAGE')"
              @click.stop="emit('duplicateStage', stage)"
            >
              <i class="i-lucide-copy text-sm" />
            </button>
            <button
              class="inline-flex h-7 w-7 items-center justify-center rounded-lg text-n-slate-10 transition-colors hover:bg-n-surface-1/80 hover:text-n-slate-12"
              :title="t('KANBAN.COLUMN_ACTIONS.ADD_STAGE')"
              @click.stop="emit('addStageAfter', stage)"
            >
              <i class="i-lucide-plus text-sm" />
            </button>
          </template>
        </div>
      </div>

      <div v-if="totalValue > 0" class="mt-1 flex items-center gap-1.5">
        <div class="flex items-center gap-1 rounded-lg border border-n-teal-6/30 bg-n-teal-3/40 px-2 py-0.5">
          <i class="i-lucide-trending-up text-xs text-n-teal-10" />
          <span class="text-xs font-medium text-n-teal-11">
            {{ formatCurrency(totalValue) }}
          </span>
        </div>
      </div>

      <Transition name="fade">
        <div
          v-if="isOverLimit"
          class="mt-1 flex items-center gap-2 rounded-xl border border-n-ruby-7/30 bg-n-ruby-3 px-3 py-2 text-[11px] font-medium text-n-ruby-11"
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
      class="custom-scrollbar-inside flex min-h-[150px] flex-1 flex-col gap-3 overflow-x-hidden overflow-y-auto p-3"
      ghost-class="ghost-card"
      drag-class="dragging-card"
      @change="handleChange"
    >
      <template #item="{ element }">
        <div @click="handleCardClick(element)" class="cursor-pointer transition-transform active:scale-[0.99]">
          <KanbanCard 
            :conversation="element" 
            :visible-attributes="visibleAttributes"
            @contextmenu="emit('cardContextmenu', $event)"
          />
        </div>
      </template>

      <template #footer v-if="!conversations.length">
        <div class="flex flex-col items-center justify-center gap-3 py-8 text-center">
          <p class="px-4 text-xs font-medium uppercase tracking-wide text-n-slate-10">
            {{ t('KANBAN.EMPTY_COLUMN') }}
          </p>
          <Button
            sm
            slate
            ghost
            icon="i-lucide-plus"
            :label="t('KANBAN.COLUMN_ACTIONS.ADD_TASK')"
            @click.stop="emit('addItem', stage)"
          />
        </div>
      </template>

      <template #footer v-else>
        <div class="px-3 pb-3 pt-1">
          <Button
            sm
            slate
            ghost
            icon="i-lucide-plus"
            class="w-full justify-center"
            :label="t('KANBAN.COLUMN_ACTIONS.ADD_TASK')"
            @click.stop="emit('addItem', stage)"
          />
        </div>
      </template>
    </Draggable>
  </div>
</template>

<style scoped>
/* Estilo para o card fantasma (onde ele vai cair) */
.ghost-card {
  opacity: 0.35;
  background: rgb(226 232 240) !important;
  border: 1px dashed rgb(148 163 184) !important;
  border-radius: 1rem;
}

.dragging-card {
  transform: rotate(2deg);
  cursor: grabbing !important;
}

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
  background: #64748b;
}

.fade-enter-active, .fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>
