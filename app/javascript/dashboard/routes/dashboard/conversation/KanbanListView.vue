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
  <div class="flex flex-col h-full bg-white">
    <!-- Header com controles -->
    <div class="flex items-center justify-between p-4 border-b border-slate-200">
      <div class="flex items-center gap-3">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            v-model="selectAll"
            type="checkbox"
            class="w-4 h-4 rounded border-slate-300 text-woot-600 focus:ring-woot-500"
            @change="toggleSelectAll"
          />
          <span class="text-sm font-medium text-slate-600">
            {{ localSelectedItems.length > 0 ? `${localSelectedItems.length} selecionado(s)` : 'Selecionar todos' }}
          </span>
        </label>
      </div>
      
      <div class="flex items-center gap-2">
        <span class="text-sm text-slate-500">{{ sortedConversations.length }} tarefas</span>
      </div>
    </div>

    <!-- Tabela -->
    <div class="flex-1 overflow-auto">
      <table class="w-full">
        <thead class="bg-slate-50 sticky top-0 z-10 border-b border-slate-200">
          <tr>
            <th class="w-12 p-3"></th>
            <th 
              class="text-left p-3 text-xs font-bold text-slate-600 uppercase tracking-wider cursor-pointer hover:bg-slate-100 transition-colors"
              @click="setSortBy('title')"
            >
              <div class="flex items-center gap-2">
                Tarefa
                <i v-if="sortBy === 'title'" :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
              </div>
            </th>
            <th class="text-left p-3 text-xs font-bold text-slate-600 uppercase tracking-wider w-40">
              Estágio
            </th>
            <th 
              class="text-left p-3 text-xs font-bold text-slate-600 uppercase tracking-wider cursor-pointer hover:bg-slate-100 transition-colors w-32"
              @click="setSortBy('priority')"
            >
              <div class="flex items-center gap-2">
                Prioridade
                <i v-if="sortBy === 'priority'" :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
              </div>
            </th>
            <th class="text-left p-3 text-xs font-bold text-slate-600 uppercase tracking-wider w-32">
              Agente
            </th>
            <th 
              class="text-right p-3 text-xs font-bold text-slate-600 uppercase tracking-wider cursor-pointer hover:bg-slate-100 transition-colors w-32"
              @click="setSortBy('value')"
            >
              <div class="flex items-center justify-end gap-2">
                Valor
                <i v-if="sortBy === 'value'" :class="sortOrder === 'asc' ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'" class="text-sm" />
              </div>
            </th>
            <th 
              class="text-left p-3 text-xs font-bold text-slate-600 uppercase tracking-wider cursor-pointer hover:bg-slate-100 transition-colors w-40"
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
            class="border-b border-slate-100 hover:bg-slate-50 transition-colors cursor-pointer"
            :class="{ 'bg-woot-50': isSelected(conversation.id) }"
            @click="handleRowClick(conversation)"
            @contextmenu.prevent="$emit('contextmenu', { event: $event, conversation })"
          >
            <td class="p-3">
              <input
                :checked="isSelected(conversation.id)"
                type="checkbox"
                class="w-4 h-4 rounded border-slate-300 text-woot-600 focus:ring-woot-500"
                @click.stop="toggleItem(conversation.id)"
              />
            </td>
            <td class="p-3">
              <div class="flex flex-col gap-1">
                <div class="flex items-center gap-2">
                  <span class="font-semibold text-slate-900 text-sm">
                    {{ conversation.custom_attributes?.kanban_title || conversation.meta?.sender?.name || 'Sem título' }}
                  </span>
                  <span v-if="conversation.priority === 'urgent'" class="text-red-500">
                    <i class="i-lucide-alert-circle text-sm" />
                  </span>
                </div>
                <p v-if="conversation.custom_attributes?.kanban_description" class="text-xs text-slate-500 line-clamp-1">
                  {{ conversation.custom_attributes.kanban_description }}
                </p>
              </div>
            </td>
            <td class="p-3">
              <div 
                class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold"
                :style="{ 
                  backgroundColor: `${getStageInfo(conversation).color}20`,
                  color: getStageInfo(conversation).color,
                  borderLeft: `3px solid ${getStageInfo(conversation).color}`
                }"
              >
                {{ getStageInfo(conversation).title || 'Sem estágio' }}
              </div>
            </td>
            <td class="p-3">
              <span 
                v-if="conversation.priority"
                class="inline-flex px-2 py-1 rounded text-xs font-semibold border"
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
                  class="w-6 h-6 rounded-full object-cover"
                />
                <span class="text-sm text-slate-700">{{ conversation.meta.assignee.name }}</span>
              </div>
              <span v-else class="text-xs text-slate-400">Não atribuído</span>
            </td>
            <td class="p-3 text-right">
              <span 
                v-if="conversation.custom_attributes?.deal_value"
                class="font-semibold text-emerald-600 text-sm"
              >
                {{ formatCurrency(conversation.custom_attributes.deal_value) }}
              </span>
              <span v-else class="text-xs text-slate-300">-</span>
            </td>
            <td class="p-3">
              <span class="text-xs text-slate-500">
                {{ formatTime(conversation.last_activity_at) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Empty state -->
      <div
        v-if="sortedConversations.length === 0 && !isLoading"
        class="flex flex-col items-center justify-center p-12 text-center"
      >
        <i class="i-lucide-inbox text-6xl text-slate-300 mb-4" />
        <h3 class="text-lg font-semibold text-slate-700 mb-2">
          Nenhuma tarefa encontrada
        </h3>
        <p class="text-sm text-slate-500">
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
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
