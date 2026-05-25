<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import { CMD_OPEN_KANBAN_MODAL } from 'dashboard/helper/commandbar/events';
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
    const stageId = conversation.value?.custom_attributes?.[board.customAttributeKey];
    return !!stageId;
  });

  return boardWithStage || kanbanConfig.value.boards[0];
});

const currentStage = computed(() => {
  if (!currentBoard.value || !conversation.value?.custom_attributes) return null;
  const stageId = conversation.value.custom_attributes[currentBoard.value.customAttributeKey];
  return currentBoard.value.stages.find(s => s.id === stageId);
});

const dealValue = computed(() => {
  return conversation.value?.custom_attributes?.deal_value;
});

const kanbanTitle = computed(() => {
  return conversation.value?.custom_attributes?.kanban_title;
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
  emitter.on(CMD_OPEN_KANBAN_MODAL, () => {
    showModal.value = true;
  });
});

onUnmounted(() => {
  emitter.off(CMD_OPEN_KANBAN_MODAL);
});
</script>

<template>
  <div class="rounded-xl border border-n-weak bg-n-surface-1 p-4">
    <div v-if="!currentBoard">
      <p class="text-xs text-n-slate-11">{{ $t('KANBAN.SIDEBAR.NO_BOARD') }}</p>
    </div>

    <div v-else>
      <div v-if="currentStage" class="space-y-3">
        <div class="flex items-center justify-between">
          <span 
            class="rounded-lg px-2 py-1 text-xs font-medium uppercase tracking-wide"
            :style="{ backgroundColor: `${currentStage.color}20`, color: currentStage.color }"
          >
            {{ currentStage.name }}
          </span>
          <button 
            @click="showModal = true"
            class="text-xs font-medium text-n-blue-11 hover:underline"
          >
            {{ $t('KANBAN.SIDEBAR.EDIT') }}
          </button>
        </div>

        <div v-if="kanbanTitle" class="text-sm font-medium text-n-slate-12">
          {{ kanbanTitle }}
        </div>

        <div v-if="dealValue" class="flex items-center gap-1 text-sm font-medium text-n-teal-11">
          <i class="i-lucide-dollar-sign text-xs" />
          {{ formatCurrency(dealValue) }}
        </div>
      </div>

      <div v-else class="text-center py-2">
        <p class="mb-3 text-xs text-n-slate-11">{{ $t('KANBAN.SIDEBAR.NOT_IN_KANBAN') }}</p>
        <button
          @click="showModal = true"
          class="w-full rounded-lg bg-n-brand/10 py-2 text-sm font-medium text-n-blue-11 transition-colors hover:bg-n-brand/15"
        >
          {{ $t('KANBAN.SIDEBAR.ADD_TO_KANBAN') }}
        </button>
      </div>
    </div>

    <KanbanItemModal
      v-if="showModal && currentBoard"
      :show="showModal"
      :board="currentBoard"
      :item="currentStage ? conversation : null"
      :conversation-id="props.conversationId"
      :stage-id="currentStage?.id || currentBoard.stages[0]?.id"
      @close="showModal = false"
      @save="handleSave"
    />
  </div>
</template>
