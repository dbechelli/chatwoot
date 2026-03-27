<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
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
const router = useRouter();

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
</script>

<template>
  <div class="flex h-full flex-col overflow-hidden rounded-2xl border border-n-weak bg-n-surface-1">
    <div class="flex items-center justify-between border-b border-n-weak px-4 py-4">
      <div class="flex items-center gap-3">
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
      </div>
      
      <div class="flex items-center gap-2">
        <span class="rounded-lg bg-n-slate-2 px-2 py-1 text-sm font-medium text-n-slate-11">{{ sortedConversations.length }} tarefas</span>
      </div>
    </div>

    <div class="flex-1 overflow-auto">
      <table class="w-full">
        <thead class="sticky top-0 z-10 border-b border-n-weak bg-n-slate-2/90 backdrop-blur">
          <tr>
            <th class="w-12 p-3"></th>
            <th 
              class="cursor-pointer p-3 text-left text-xs font-medium uppercase tracking-wide text-n-slate-10 transition-colors hover:bg-n-slate-3"
              @click="setSortBy('title')"
            >
              <div class="flex items-center gap-2">
                Tarefa
                <i v-if="sortBy === 'title'" :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
              </div>
            </th>
            <th class="w-40 p-3 text-left text-xs font-medium uppercase tracking-wide text-n-slate-10">
              Estágio
            </th>
            <th 
              class="w-32 cursor-pointer p-3 text-left text-xs font-medium uppercase tracking-wide text-n-slate-10 transition-colors hover:bg-n-slate-3"
              @click="setSortBy('priority')"
            >
              <div class="flex items-center gap-2">
                Prioridade
                <i v-if="sortBy === 'priority'" :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
              </div>
            </th>
            <th class="w-32 p-3 text-left text-xs font-medium uppercase tracking-wide text-n-slate-10">
              Agente
            </th>
            <th 
              class="w-32 cursor-pointer p-3 text-right text-xs font-medium uppercase tracking-wide text-n-slate-10 transition-colors hover:bg-n-slate-3"
              @click="setSortBy('value')"
            >
              <div class="flex items-center justify-end gap-2">
                Valor
                <i v-if="sortBy === 'value'" :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
              </div>
            </th>
            <th 
              class="w-40 cursor-pointer p-3 text-left text-xs font-medium uppercase tracking-wide text-n-slate-10 transition-colors hover:bg-n-slate-3"
              @click="setSortBy('last_activity')"
            >
              <div class="flex items-center gap-2">
                Atualização
                <i v-if="sortBy === 'last_activity'" :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
              </div>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="conversation in sortedConversations"
            :key="conversation.id"
            class="cursor-pointer border-b border-n-weak/70 transition-colors hover:bg-n-slate-2/60"
            :class="{ 'bg-n-brand/5': isSelected(conversation.id) }"
            @click="handleRowClick(conversation)"
            @contextmenu.prevent="$emit('contextmenu', { event: $event, conversation })"
          >
            <td class="p-3">
              <input
                :checked="isSelected(conversation.id)"
                type="checkbox"
                class="h-4 w-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
                @click.stop="toggleItem(conversation.id)"
              />
            </td>
            <td class="p-3">
              <div class="flex flex-col gap-1">
                <div class="flex items-center gap-2">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ conversation.custom_attributes?.kanban_title || conversation.meta?.sender?.name || 'Sem título' }}
                  </span>
                  <span v-if="conversation.priority === 'urgent'" class="text-n-ruby-11">
                    <i class="i-lucide-alert-circle text-sm" />
                  </span>
                </div>
                <p v-if="conversation.custom_attributes?.kanban_description" class="line-clamp-1 text-xs text-n-slate-11">
                  {{ conversation.custom_attributes.kanban_description }}
                </p>
              </div>
            </td>
            <td class="p-3">
              <div 
                class="inline-flex items-center gap-1.5 rounded-xl border px-2.5 py-1 text-xs font-medium"
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
                {{ getStageInfo(conversation).title || 'Sem estágio' }}
              </div>
            </td>
            <td class="p-3">
              <span 
                v-if="conversation.priority"
                class="inline-flex rounded-lg border px-2 py-1 text-xs font-medium"
                :class="priorityColors[conversation.priority]"
              >
                {{ t(`CONVERSATION.PRIORITY.OPTIONS.${conversation.priority.toUpperCase()}`) }}
              </span>
            </td>
            <td class="p-3">
              <div v-if="conversation.meta?.assignee" class="flex items-center gap-2">
                <img
                  v-if="conversation.meta.assignee.thumbnail"
                  :src="conversation.meta.assignee.thumbnail"
                  :alt="conversation.meta.assignee.name"
                  class="h-6 w-6 rounded-full border border-n-weak object-cover"
                />
                <span class="text-sm text-n-slate-12">{{ conversation.meta.assignee.name }}</span>
              </div>
              <span v-else class="text-xs text-n-slate-10">Não atribuído</span>
            </td>
            <td class="p-3 text-right">
              <span 
                v-if="conversation.custom_attributes?.deal_value"
                class="text-sm font-medium text-n-teal-11"
              >
                {{ formatCurrency(conversation.custom_attributes.deal_value) }}
              </span>
              <span v-else class="text-xs text-n-slate-9">-</span>
            </td>
            <td class="p-3">
              <span class="text-xs text-n-slate-11">
                {{ formatTime(conversation.last_activity_at) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>

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
