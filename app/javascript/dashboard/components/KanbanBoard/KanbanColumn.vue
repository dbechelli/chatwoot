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

const emit = defineEmits(['update:conversations', 'stageChange', 'cardClick', 'cardContextmenu', 'addItem']);

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

const hexToRgb = value => {
  const normalized = value.replace('#', '');
  const expanded = normalized.length === 3
    ? normalized.split('').map(char => `${char}${char}`).join('')
    : normalized;

  const numeric = Number.parseInt(expanded, 16);

  return {
    red: (numeric >> 16) & 255,
    green: (numeric >> 8) & 255,
    blue: numeric & 255,
  };
};

const rgba = (value, alpha) => {
  const { red, green, blue } = hexToRgb(value);
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
};

const isLightColor = computed(() => {
  const { red, green, blue } = hexToRgb(props.color);
  const luminance = (red * 299 + green * 587 + blue * 114) / 1000;
  return luminance > 160;
});

const columnStyle = computed(() => ({
  backgroundColor: isOverLimit.value ? rgba('#ef4444', 0.08) : rgba(props.color, 0.08),
  borderColor: isOverLimit.value ? rgba('#ef4444', 0.18) : rgba(props.color, 0.18),
}));

const headerStyle = computed(() => ({
  backgroundColor: isOverLimit.value ? rgba('#ef4444', 0.92) : rgba(props.color, 0.82),
  borderColor: isOverLimit.value ? rgba('#ef4444', 0.3) : rgba(props.color, 0.22),
  color: isLightColor.value ? '#111827' : '#ffffff',
}));

const counterStyle = computed(() => ({
  backgroundColor: isLightColor.value ? 'rgba(255,255,255,0.55)' : 'rgba(255,255,255,0.16)',
  borderColor: isLightColor.value ? 'rgba(17,24,39,0.08)' : 'rgba(255,255,255,0.18)',
  color: isLightColor.value ? '#111827' : '#ffffff',
}));
</script>

<template>
  <div 
    class="flex h-full min-h-0 flex-col overflow-hidden rounded-2xl border transition-colors"
    :style="columnStyle"
  >
    <div class="flex flex-col gap-2 border-b px-3 py-3 md:px-4 md:py-4" :style="headerStyle">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2.5 overflow-hidden">
          <div
            class="h-2.5 w-2.5 flex-shrink-0 rounded-full"
            :style="{ backgroundColor: isLightColor ? 'rgba(17,24,39,0.55)' : 'rgba(255,255,255,0.7)' }"
          />
          <h3 class="truncate text-sm font-medium uppercase tracking-wide">
            {{ title }}
          </h3>
        </div>
        
        <div
          class="flex items-center gap-1 rounded-lg border px-2 py-0.5 text-[11px] font-medium"
          :style="counterStyle"
        >
          <span>{{ conversations.length }}</span>
          <span v-if="wipLimit" class="opacity-70">/ {{ wipLimit }}</span>
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
      <template #header>
        <button
          type="button"
          class="inline-flex items-center gap-2 self-start rounded-xl px-2 py-1 text-sm font-medium text-n-slate-12 transition hover:bg-white/55"
          @click.stop="emit('addItem', stage)"
        >
          <i class="i-lucide-plus text-base" />
          {{ t('KANBAN.MODAL.NEW_ITEM') }}
        </button>
      </template>

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
        <div class="flex flex-1 items-center justify-center py-8 text-center">
          <p class="px-4 text-xs font-medium uppercase tracking-wide text-n-slate-10/80">
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
