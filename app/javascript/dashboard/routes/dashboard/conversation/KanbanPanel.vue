<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import KanbanItemModal from './KanbanItemModal.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();
const { t } = useI18n();

const showModal = ref(false);
const kanbanConfig = ref(null);
const isLoading = ref(false);

const conversation = computed(() => store.getters.getSelectedChat);

// Fetch Kanban Config (Boards)
const loadKanbanConfig = async () => {
  try {
    const { data } = await window.axios.get(`/api/v1/accounts/${store.getters.getCurrentAccountId}/kanban_settings`);
    kanbanConfig.value = data;
  } catch (error) {
    console.error('Failed to load kanban config', error);
  }
};

// Determine which board this conversation belongs to (if any)
// For simplicity, we'll use the first board or the one matching the stage attribute
const currentBoard = computed(() => {
  if (!kanbanConfig.value?.boards?.length) return null;
  
  // Try to find a board where the conversation has a stage
  const boardWithStage = kanbanConfig.value.boards.find(board => {
    const stageId = conversation.value.custom_attributes?.[board.customAttributeKey];
    return !!stageId;
  });

  return boardWithStage || kanbanConfig.value.boards[0];
});

const currentStage = computed(() => {
  if (!currentBoard.value || !conversation.value.custom_attributes) return null;
  const stageId = conversation.value.custom_attributes[currentBoard.value.customAttributeKey];
  return currentBoard.value.stages.find(s => s.id === stageId);
});

const dealValue = computed(() => {
  return conversation.value.custom_attributes?.deal_value;
});

const kanbanTitle = computed(() => {
  return conversation.value.custom_attributes?.kanban_title;
});

const formatCurrency = (value) => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);
};

const handleSave = () => {
  // Refresh conversation to get updated attributes
  store.dispatch('getConversation', props.conversationId);
};

onMounted(() => {
  loadKanbanConfig();
});
</script>

<template>
  <div class="p-4 bg-white rounded-md border border-slate-100">
    <div v-if="!currentBoard">
      <p class="text-xs text-slate-500">Nenhum quadro Kanban configurado.</p>
    </div>

    <div v-else>
      <div v-if="currentStage" class="space-y-3">
        <div class="flex items-center justify-between">
          <span 
            class="px-2 py-1 rounded text-xs font-bold uppercase tracking-wider"
            :style="{ backgroundColor: `${currentStage.color}20`, color: currentStage.color }"
          >
            {{ currentStage.name }}
          </span>
          <button 
            @click="showModal = true"
            class="text-xs text-blue-600 hover:underline font-medium"
          >
            Editar
          </button>
        </div>

        <div v-if="kanbanTitle" class="font-bold text-sm text-slate-800">
          {{ kanbanTitle }}
        </div>

        <div v-if="dealValue" class="flex items-center gap-1 text-emerald-700 font-bold text-sm">
          <i class="i-lucide-dollar-sign text-xs" />
          {{ formatCurrency(dealValue) }}
        </div>
      </div>

      <div v-else class="text-center py-2">
        <p class="text-xs text-slate-500 mb-3">Esta conversa não está no Kanban.</p>
        <button
          @click="showModal = true"
          class="w-full py-2 bg-blue-50 text-blue-600 rounded-md text-sm font-bold hover:bg-blue-100 transition-colors"
        >
          Adicionar ao Kanban
        </button>
      </div>
    </div>

    <KanbanItemModal
      v-if="showModal && currentBoard"
      :show="showModal"
      :board="currentBoard"
      :item="currentStage ? conversation : null"
      :stage-id="currentStage?.id || currentBoard.stages[0]?.id"
      @close="showModal = false"
      @save="handleSave"
    />
  </div>
</template>
