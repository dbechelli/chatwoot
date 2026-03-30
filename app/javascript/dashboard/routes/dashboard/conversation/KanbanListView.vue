<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const props = defineProps({
  conversations: { type: Array, required: true },
  stages: { type: Array, required: true },
  currentBoard: { type: Object, required: true },
  isLoading: { type: Boolean, default: false },
  selectedItems: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:selectedItems', 'stageChange', 'openItem', 'contextmenu']);

const { t } = useI18n();

const sortBy = ref('last_activity');
const sortOrder = ref('desc');
const selectAll = ref(false);

const localSelectedItems = computed({
  get: () => props.selectedItems,
  set: (value) => emit('update:selectedItems', value),
});

const sortedConversations = computed(() => {
  const items = [...props.conversations];
  
  return items.sort((a, b) => {
    let aVal, bVal;
    
    switch (sortBy.value) {
      case 'last_activity':
        aVal = a.last_activity_at || 0;
        bVal = b.last_activity_at || 0;
        break;
      case 'title':
        aVal = a.custom_attributes?.kanban_title || a.meta?.sender?.name || '';
        bVal = b.custom_attributes?.kanban_title || b.meta?.sender?.name || '';
        break;
      case 'priority':
        const priorities = { urgent: 4, high: 3, medium: 2, low: 1 };
        aVal = priorities[a.priority] || 0;
        bVal = priorities[b.priority] || 0;
        break;
      case 'value':
        aVal = a.custom_attributes?.deal_value || 0;
        bVal = b.custom_attributes?.deal_value || 0;
        break;
      default:
        return 0;
    }
    
    if (sortOrder.value === 'asc') {
      return aVal > bVal ? 1 : -1;
    }
    return aVal < bVal ? 1 : -1;
  });
});

const toggleSelectAll = () => {
  if (selectAll.value) {
    localSelectedItems.value = sortedConversations.value.map(c => c.id);
  } else {
    localSelectedItems.value = [];
  }
};

const toggleItem = (id) => {
  const index = localSelectedItems.value.indexOf(id);
  if (index === -1) {
    localSelectedItems.value = [...localSelectedItems.value, id];
  } else {
    localSelectedItems.value = localSelectedItems.value.filter(i => i !== id);
  }
};

const isSelected = (id) => localSelectedItems.value.includes(id);

const getStageInfo = (conversation) => {
  const stageId = conversation.custom_attributes?.[props.currentBoard.customAttributeKey];
  return props.stages.find(s => s.stage === stageId) || {};
};

const getConversationTitle = conversation => {
  return conversation.custom_attributes?.kanban_title || conversation.meta?.sender?.name || 'Sem titulo';
};

const getConversationDescription = conversation => {
  return conversation.custom_attributes?.kanban_description || '';
};

const getAssigneeName = conversation => {
  return conversation.meta?.assignee?.name || 'Nao atribuido';
};

const getPriorityLabel = priority => {
  if (!priority) {
    return null;
  }

  return t(`CONVERSATION.PRIORITY.OPTIONS.${priority.toUpperCase()}`);
};

const formatCurrency = (value) => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value || 0);
};

const formatTime = (timestamp) => {
  return formatDistanceToNow(new Date(timestamp * 1000), {
    addSuffix: true,
    locale: ptBR,
  });
};

const priorityColors = {
  urgent: 'bg-red-100 text-red-700 border-red-300',
  high: 'bg-yellow-100 text-yellow-700 border-yellow-300',
  medium: 'bg-blue-100 text-blue-700 border-blue-300',
  low: 'bg-green-100 text-green-700 border-green-300',
};

const handleRowClick = (conversation) => {
  if (localSelectedItems.value.length > 0) {
    toggleItem(conversation.id);
  } else {
    emit('openItem', conversation);
  }
};

const setSortBy = (field) => {
  if (sortBy.value === field) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortBy.value = field;
    sortOrder.value = 'desc';
  }
};

const sortOptions = [
  { value: 'last_activity', label: 'Atualizacao' },
  { value: 'title', label: 'Tarefa' },
  { value: 'priority', label: 'Prioridade' },
  { value: 'value', label: 'Valor' },
];
</script>

<template>
  <div class="flex h-full min-h-0 flex-col rounded-2xl border border-n-weak bg-n-surface-1">
    <div class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak px-4 py-3 md:px-5">
      <div class="flex flex-wrap items-center gap-3">
        <label class="flex cursor-pointer items-center gap-2">
          <input
            v-model="selectAll"
            type="checkbox"
            class="h-4 w-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
            @change="toggleSelectAll"
          />
          <span class="text-sm font-medium text-n-slate-11">
            {{ localSelectedItems.length > 0 ? `${localSelectedItems.length} selecionado(s)` : 'Selecionar todos' }}
          </span>
        </label>
        <span class="rounded-lg bg-n-slate-2 px-2 py-1 text-sm font-medium text-n-slate-11">
          {{ sortedConversations.length }} tarefas
        </span>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
          Ordenar
        </label>
        <select
          v-model="sortBy"
          class="h-9 rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
        >
          <option v-for="option in sortOptions" :key="option.value" :value="option.value">
            {{ option.label }}
          </option>
        </select>
        <button
          class="inline-flex h-9 items-center gap-2 rounded-xl border border-n-weak px-3 text-sm font-medium text-n-slate-11 transition hover:bg-n-slate-2"
          type="button"
          @click="sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'"
        >
          <i :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
          {{ sortOrder === 'asc' ? 'Crescente' : 'Decrescente' }}
        </button>
      </div>
    </div>

    <div class="custom-scrollbar flex-1 overflow-y-auto overflow-x-hidden p-3 md:p-4">
      <div
        v-if="sortedConversations.length"
        class="grid grid-cols-1 gap-3 xl:grid-cols-2"
      >
        <article
          v-for="conversation in sortedConversations"
          :key="conversation.id"
          class="cursor-pointer rounded-2xl border border-n-weak bg-n-surface-1 p-4 shadow-sm transition hover:border-n-brand/30 hover:bg-n-slate-2/40"
          :class="{ 'border-n-brand bg-n-brand/5': isSelected(conversation.id) }"
          @click="handleRowClick(conversation)"
          @contextmenu.prevent="$emit('contextmenu', { event: $event, conversation })"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="flex min-w-0 items-start gap-3">
              <input
                :checked="isSelected(conversation.id)"
                type="checkbox"
                class="mt-1 h-4 w-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
                @click.stop="toggleItem(conversation.id)"
              />

              <div class="min-w-0 space-y-2">
                <div class="flex min-w-0 items-center gap-2">
                  <h3 class="truncate text-sm font-medium text-n-slate-12 md:text-base">
                    {{ getConversationTitle(conversation) }}
                  </h3>
                  <span v-if="conversation.priority === 'urgent'" class="shrink-0 text-n-ruby-11">
                    <i class="i-lucide-alert-circle text-sm" />
                  </span>
                </div>

                <p
                  v-if="getConversationDescription(conversation)"
                  class="line-clamp-2 text-sm text-n-slate-11"
                >
                  {{ getConversationDescription(conversation) }}
                </p>

                <div class="flex flex-wrap items-center gap-2">
                  <div
                    class="inline-flex max-w-full items-center gap-1.5 rounded-xl border px-2.5 py-1 text-xs font-medium"
                    :style="{
                      backgroundColor: `${getStageInfo(conversation).color}20`,
                      color: getStageInfo(conversation).color,
                      borderColor: `${getStageInfo(conversation).color}40`
                    }"
                  >
                    <span
                      class="h-2 w-2 rounded-full"
                      :style="{ backgroundColor: getStageInfo(conversation).color }"
                    />
                    <span class="truncate">
                      {{ getStageInfo(conversation).title || 'Sem estagio' }}
                    </span>
                  </div>

                  <span
                    v-if="conversation.priority"
                    class="inline-flex rounded-lg border px-2 py-1 text-xs font-medium"
                    :class="priorityColors[conversation.priority]"
                  >
                    {{ getPriorityLabel(conversation.priority) }}
                  </span>
                </div>
              </div>
            </div>

            <div class="flex flex-col items-start gap-1 text-left md:items-end md:text-right">
              <span
                v-if="conversation.custom_attributes?.deal_value"
                class="text-sm font-semibold text-n-teal-11"
              >
                {{ formatCurrency(conversation.custom_attributes.deal_value) }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{ formatTime(conversation.last_activity_at) }}
              </span>
            </div>
          </div>

          <div class="mt-4 grid grid-cols-1 gap-3 border-t border-n-weak pt-3 md:grid-cols-2">
            <div class="flex items-center gap-2 min-w-0">
              <img
                v-if="conversation.meta?.assignee?.thumbnail"
                :src="conversation.meta.assignee.thumbnail"
                :alt="conversation.meta.assignee.name"
                class="h-7 w-7 rounded-full border border-n-weak object-cover"
              />
              <div class="min-w-0">
                <p class="text-xs uppercase tracking-wide text-n-slate-9">Agente</p>
                <p class="truncate text-sm text-n-slate-12">{{ getAssigneeName(conversation) }}</p>
              </div>
            </div>

            <div class="min-w-0">
              <p class="text-xs uppercase tracking-wide text-n-slate-9">Contato</p>
              <p class="truncate text-sm text-n-slate-12">
                {{ conversation.meta?.sender?.name || 'Sem contato' }}
              </p>
            </div>
          </div>
        </article>
      </div>

      <div
        v-if="sortedConversations.length === 0 && !isLoading"
        class="flex flex-col items-center justify-center p-12 text-center"
      >
        <i class="i-lucide-inbox mb-4 text-6xl text-n-slate-8" />
        <h3 class="mb-2 text-lg font-medium text-n-slate-12">
          Nenhuma tarefa encontrada
        </h3>
        <p class="text-sm text-n-slate-11">
          Ajuste os filtros ou crie uma nova tarefa
        </p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.line-clamp-1 {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
