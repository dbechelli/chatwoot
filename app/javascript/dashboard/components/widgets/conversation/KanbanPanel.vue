<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanItemModal from 'dashboard/routes/dashboard/conversation/KanbanItemModal.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const store = useStore();
const { t } = useI18n();

const isLoading = ref(false);
const selectedBoard = ref(null);
const currentStage = ref(null);
const dealValue = ref(0);
const priority = ref('medium');
const dueDate = ref('');
const startDate = ref('');
const notes = ref('');
const showItemModal = ref(false);
const showRemoveModal = ref(false);

const kanbanBoards = computed(() => store.getters['kanban/getBoards'] || []);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const conversation = computed(() => 
  store.getters.getConversationById(props.conversationId)
);

const availableBoards = computed(() => {
  const currentUserId = store.getters.getCurrentUser?.id;
  return kanbanBoards.value.filter(board => {
    if (!board.agent_ids || board.agent_ids.length === 0) return true;
    return board.agent_ids.includes(currentUserId);
  });
});

const currentBoardStages = computed(() => {
  if (!selectedBoard.value) return [];
  return selectedBoard.value.stages || [];
});

const currentStageOption = computed(() => {
  return currentBoardStages.value.find(stage => stage.id === currentStage.value) || null;
});

const assignedBoardAgents = computed(() => {
  if (!selectedBoard.value?.agent_ids?.length) return [];
  return agents.value.filter(agent => selectedBoard.value.agent_ids.includes(agent.id));
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

const currentStageStyle = computed(() => {
  const rgb = hexToRgb(currentStageOption.value?.color);

  if (!rgb || !currentStageOption.value?.color) {
    return {};
  }

  return {
    backgroundColor: `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.12)`,
    color: currentStageOption.value.color,
    borderColor: `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, 0.22)`,
  };
});

const isInKanban = computed(() => {
  if (!selectedBoard.value || !conversation.value) return false;
  const attrKey = selectedBoard.value.customAttributeKey;
  return !!conversation.value.custom_attributes?.[attrKey];
});

const loadCurrentState = () => {
  if (!conversation.value || !selectedBoard.value) return;
  
  const attrs = conversation.value.custom_attributes || {};
  const attrKey = selectedBoard.value.customAttributeKey;
  
  currentStage.value = attrs[attrKey] || null;
  dealValue.value = attrs.deal_value || 0;
  notes.value = attrs.kanban_notes || '';
  dueDate.value = attrs.kanban_due_date || '';
  startDate.value = attrs.kanban_start_date || '';
  priority.value = conversation.value.priority || 'medium';
};

const addToKanban = async () => {
  if (!selectedBoard.value || !currentStage.value) {
    useAlert(t('KANBAN.SIDEBAR.SELECT_BOARD_AND_STAGE'));
    return;
  }
  
  isLoading.value = true;
  try {
    const attrKey = selectedBoard.value.customAttributeKey;
    const customAttributes = {
      ...conversation.value.custom_attributes,
      [attrKey]: currentStage.value,
      deal_value: dealValue.value || 0,
      kanban_notes: notes.value,
      kanban_due_date: dueDate.value,
      kanban_start_date: startDate.value,
      kanban_title: conversation.value.meta?.sender?.name || `Conversa #${conversation.value.id}`,
    };
    
    await store.dispatch('updateCustomAttributes', {
      conversationId: props.conversationId,
      customAttributes,
    });
    
    if (priority.value !== conversation.value.priority) {
      await store.dispatch('updateConversation', {
        conversationId: props.conversationId,
        priority: priority.value,
      });
    }
    
    useAlert(t('KANBAN.SIDEBAR.ADD_SUCCESS'));
  } catch (error) {
    useAlert(t('KANBAN.SIDEBAR.ADD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const updateStage = async (newStage) => {
  if (!selectedBoard.value || !newStage) return;

  isLoading.value = true;
  try {
    const attrKey = selectedBoard.value.customAttributeKey;
    const customAttributes = {
      ...conversation.value.custom_attributes,
      [attrKey]: newStage,
    };
    
    await store.dispatch('updateCustomAttributes', {
      conversationId: props.conversationId,
      customAttributes,
    });
    
    currentStage.value = newStage;
        useAlert(t('KANBAN.SIDEBAR.UPDATE_STAGE_SUCCESS'));
  } catch (error) {
        useAlert(t('KANBAN.SIDEBAR.UPDATE_STAGE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const removeFromKanban = async () => {
  isLoading.value = true;
  try {
    const attrKey = selectedBoard.value.customAttributeKey;
    const customAttributes = {
      ...conversation.value.custom_attributes,
      [attrKey]: null,
    };
    
    await store.dispatch('updateCustomAttributes', {
      conversationId: props.conversationId,
      customAttributes,
    });
    
    currentStage.value = null;
    showRemoveModal.value = false;
    useAlert(t('KANBAN.SIDEBAR.REMOVE_SUCCESS'));
  } catch (error) {
    useAlert(t('KANBAN.SIDEBAR.REMOVE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

watch(() => selectedBoard.value, () => {
  loadCurrentState();
});

watch(() => conversation.value, () => {
  loadCurrentState();
}, { deep: true });

onMounted(async () => {
  await store.dispatch('kanban/fetch');
  
  if (availableBoards.value.length > 0) {
    selectedBoard.value = availableBoards.value.find(b => b.isDefault) || availableBoards.value[0];
  }
  
  loadCurrentState();
});

const openFullEditor = () => {
  showItemModal.value = true;
};

const handleModalSaved = () => {
  loadCurrentState();
};
</script>

<template>
  <div class="space-y-4 rounded-2xl border border-n-weak bg-n-surface-1 p-4">
    <div class="flex items-center justify-between gap-3 border-b border-n-weak pb-3">
      <div class="flex items-center gap-2">
        <h3 class="font-medium text-n-slate-12">{{ t('KANBAN.TITLE') }}</h3>
      </div>
    </div>

    <div class="space-y-4">
      <div v-if="availableBoards.length === 0" class="py-8 text-center">
        <i class="i-lucide-kanban-square mb-2 text-4xl text-n-slate-8" />
        <p class="text-sm text-n-slate-11">{{ t('KANBAN.SIDEBAR.NO_AVAILABLE_BOARDS') }}</p>
      </div>

      <div v-else class="space-y-4">
        <div class="space-y-1.5">
          <label class="block text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ t('KANBAN.BOARD') }}</label>
          <select
            v-model="selectedBoard"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
          >
            <option v-for="board in availableBoards" :key="board.id" :value="board">
              {{ board.name }}
            </option>
          </select>
        </div>

        <div class="rounded-2xl border border-n-weak bg-n-surface-1 p-3">
          <div v-if="selectedBoard" class="mb-3 flex flex-wrap items-center gap-2">
            <span class="inline-flex items-center rounded-full bg-n-slate-2 px-2.5 py-1 text-xs font-medium text-n-slate-11">
              {{ selectedBoard.name }}
            </span>
            <span
              v-if="currentStageOption"
              class="inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium"
              :style="currentStageStyle"
            >
              {{ currentStageOption.name }}
            </span>
            <span
              v-else
              class="inline-flex items-center rounded-full bg-n-amber-3 px-2.5 py-1 text-xs font-medium text-n-amber-11"
            >
              {{ t('KANBAN.SIDEBAR.NOT_IN_KANBAN') }}
            </span>
          </div>

          <div v-if="conversation" class="mb-3 rounded-xl bg-n-slate-2 p-3 text-sm text-n-slate-11">
            <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.SIDEBAR.LINKED_CONVERSATION') }}
            </p>
            <p class="mt-1 truncate font-medium text-n-slate-12">
              {{ conversation.meta?.sender?.name || t('KANBAN.UNKNOWN_CONTACT') }}
            </p>
            <p class="mt-0.5 text-xs text-n-slate-10">#{{ conversation.id }}</p>
          </div>

          <div class="space-y-3">
            <div class="space-y-1.5">
              <label class="block text-xs font-medium text-n-slate-12">{{ t('KANBAN.MODAL.STAGE') }}</label>
              <div class="flex items-center gap-2">
                <select
                  v-model="currentStage"
                  :disabled="isLoading"
                  class="min-w-0 flex-1 rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                >
                  <option value="">{{ t('KANBAN.SIDEBAR.SELECT_STAGE') }}</option>
                  <option v-for="stage in currentBoardStages" :key="stage.id" :value="stage.id">
                    {{ stage.name }}
                  </option>
                </select>
                <button
                  v-if="isInKanban"
                  :disabled="isLoading || !currentStage || currentStage === currentStageOption?.id"
                  class="inline-flex h-9 w-9 items-center justify-center rounded-lg text-n-brand transition-colors hover:bg-n-brand/10"
                  @click="updateStage(currentStage)"
                >
                  <i class="i-lucide-check text-sm" />
                </button>
              </div>
            </div>

            <div v-if="assignedBoardAgents.length" class="space-y-1.5">
              <label class="block text-xs font-medium text-n-slate-12">{{ t('KANBAN.SIDEBAR.ASSIGNED_AGENTS') }}</label>
              <div class="rounded-xl bg-n-slate-2 p-2">
                <div class="flex flex-wrap gap-1.5">
                  <span
                    v-for="agent in assignedBoardAgents"
                    :key="agent.id"
                    class="inline-flex items-center rounded-lg bg-n-surface-1 px-2 py-1 text-xs font-medium text-n-slate-11"
                  >
                    {{ agent.name }}
                  </span>
                </div>
              </div>
            </div>

            <div class="space-y-1.5">
              <label class="block text-xs font-medium text-n-slate-12">{{ t('KANBAN.MODAL.PRIORITY') }}</label>
              <div class="rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-11">
                {{ t(`KANBAN.MODAL.PRIORITY_LABEL.${priority.toUpperCase()}`) || 'Nenhuma' }}
              </div>
            </div>

            <div class="grid grid-cols-1 gap-3">
              <div class="space-y-1.5">
                <label class="block text-xs font-medium text-n-slate-12">{{ t('KANBAN.MODAL.START_DATE') }}</label>
                <input
                  v-model="startDate"
                  type="date"
                  class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                />
              </div>

              <div class="space-y-1.5">
                <label class="block text-xs font-medium text-n-slate-12">{{ t('KANBAN.MODAL.DUE_DATE') }}</label>
                <input
                  v-model="dueDate"
                  type="date"
                  class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                />
              </div>
            </div>
          </div>
        </div>

        <div class="flex gap-2">
          <Button
            v-if="!isInKanban"
            @click="addToKanban"
            :disabled="!currentStage || isLoading"
            blue
            solid
            icon="i-lucide-plus"
            class="flex-1"
            :label="t('KANBAN.SIDEBAR.ADD_TO_KANBAN')"
          />
          <Button
            v-else
            @click="openFullEditor"
            slate
            outline
            icon="i-lucide-pencil"
            class="flex-1"
            :label="t('KANBAN.SIDEBAR.EDIT_TASK')"
          />
          <Button
            v-if="isInKanban"
            @click="showRemoveModal = true"
            ruby
            ghost
            icon="i-lucide-trash-2"
            :title="t('KANBAN.SIDEBAR.REMOVE_FROM_KANBAN')"
            :aria-label="t('KANBAN.SIDEBAR.REMOVE_FROM_KANBAN')"
          />
        </div>
      </div>
    </div>

    <KanbanItemModal
      v-if="showItemModal && selectedBoard"
      :show="showItemModal"
      :board="selectedBoard"
      :stage-id="currentStage || ''"
      :item="conversation"
      :conversation-id="conversationId"
      @close="showItemModal = false"
      @save="handleModalSaved"
    />

    <Modal :show="showRemoveModal" :on-close="() => (showRemoveModal = false)">
      <div class="w-full max-w-md p-6">
        <h3 class="text-lg font-medium text-n-slate-12">
          {{ t('KANBAN.SIDEBAR.REMOVE_TITLE') }}
        </h3>
        <p class="mt-2 text-sm text-n-slate-11">
          {{ t('KANBAN.SIDEBAR.REMOVE_DESCRIPTION') }}
        </p>
        <div class="mt-5 flex justify-end gap-2">
          <Button
            slate
            outline
            sm
            :label="t('KANBAN.MODAL.CANCEL')"
            @click="showRemoveModal = false"
          />
          <Button
            ruby
            solid
            sm
            :is-loading="isLoading"
            :label="t('KANBAN.SIDEBAR.REMOVE')"
            @click="removeFromKanban"
          />
        </div>
      </div>
    </Modal>
  </div>
</template>
