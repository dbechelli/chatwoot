<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

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
const isExpanded = ref(false);

const kanbanBoards = computed(() => store.getters['kanban/getBoards'] || []);
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
    useAlert('Selecione um quadro e um estágio');
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
    
    useAlert('Tarefa adicionada ao Kanban');
    isExpanded.value = false;
  } catch (error) {
    useAlert('Erro ao adicionar ao Kanban');
  } finally {
    isLoading.value = false;
  }
};

const updateStage = async (newStage) => {
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
    useAlert('Estágio atualizado');
  } catch (error) {
    useAlert('Erro ao atualizar estágio');
  } finally {
    isLoading.value = false;
  }
};

const removeFromKanban = async () => {
  if (!confirm('Remover esta conversa do Kanban?')) return;
  
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
    useAlert('Removido do Kanban');
  } catch (error) {
    useAlert('Erro ao remover do Kanban');
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
</script>

<template>
  <div class="flex flex-col h-full bg-white border-l border-slate-200">
    <!-- Header -->
    <div class="flex items-center justify-between p-4 border-b border-slate-200">
      <div class="flex items-center gap-2">
        <i class="i-lucide-kanban-square text-woot-600 text-xl" />
        <h3 class="font-bold text-slate-900">Kanban</h3>
      </div>
      <button
        v-if="isInKanban"
        @click="isExpanded = !isExpanded"
        class="p-1 hover:bg-slate-100 rounded transition-colors"
      >
        <i :class="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'" class="text-slate-500" />
      </button>
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-y-auto p-4 space-y-4">
      <div v-if="availableBoards.length === 0" class="text-center py-8">
        <i class="i-lucide-kanban-square text-4xl text-slate-300 mb-2" />
        <p class="text-sm text-slate-500">Nenhum quadro disponível</p>
      </div>

      <div v-else>
        <!-- Board Selector -->
        <div>
          <label class="block text-xs font-semibold text-slate-600 mb-2 uppercase">
            Quadro
          </label>
          <select
            v-model="selectedBoard"
            class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none"
          >
            <option v-for="board in availableBoards" :key="board.id" :value="board">
              {{ board.name }}
            </option>
          </select>
        </div>

        <!-- Current Status -->
        <div v-if="isInKanban" class="bg-woot-50 border border-woot-200 rounded-lg p-3">
          <div class="flex items-center gap-2 mb-2">
            <i class="i-lucide-check-circle text-woot-600" />
            <span class="text-xs font-semibold text-woot-800 uppercase">No Kanban</span>
          </div>
          
          <div class="space-y-3">
            <!-- Current Stage -->
            <div>
              <label class="block text-xs font-medium text-slate-600 mb-1">
                Estágio Atual
              </label>
              <select
                v-model="currentStage"
                @change="updateStage(currentStage)"
                :disabled="isLoading"
                class="w-full px-2 py-1.5 text-sm border border-slate-200 rounded bg-white focus:border-woot-500 outline-none"
              >
                <option
                  v-for="stage in currentBoardStages"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>
            </div>

            <!-- Expanded Details -->
            <div v-if="isExpanded" class="space-y-3 pt-2 border-t border-woot-200">
              <!-- Priority -->
              <div>
                <label class="block text-xs font-medium text-slate-600 mb-1">
                  Prioridade
                </label>
                <select
                  v-model="priority"
                  class="w-full px-2 py-1.5 text-sm border border-slate-200 rounded bg-white focus:border-woot-500 outline-none"
                >
                  <option value="low">Baixa</option>
                  <option value="medium">Média</option>
                  <option value="high">Alta</option>
                  <option value="urgent">Urgente</option>
                </select>
              </div>

              <!-- Deal Value -->
              <div v-if="selectedBoard?.valueAttributeKey">
                <label class="block text-xs font-medium text-slate-600 mb-1">
                  Valor
                </label>
                <input
                  v-model.number="dealValue"
                  type="number"
                  min="0"
                  step="0.01"
                  class="w-full px-2 py-1.5 text-sm border border-slate-200 rounded focus:border-woot-500 outline-none"
                  placeholder="R$ 0,00"
                />
              </div>

              <!-- Dates -->
              <div>
                <label class="block text-xs font-medium text-slate-600 mb-1">
                  Data de Início
                </label>
                <input
                  v-model="startDate"
                  type="date"
                  class="w-full px-2 py-1.5 text-sm border border-slate-200 rounded focus:border-woot-500 outline-none"
                />
              </div>

              <div>
                <label class="block text-xs font-medium text-slate-600 mb-1">
                  Data de Vencimento
                </label>
                <input
                  v-model="dueDate"
                  type="date"
                  class="w-full px-2 py-1.5 text-sm border border-slate-200 rounded focus:border-woot-500 outline-none"
                />
              </div>

              <!-- Notes -->
              <div>
                <label class="block text-xs font-medium text-slate-600 mb-1">
                  Notas
                </label>
                <textarea
                  v-model="notes"
                  rows="3"
                  class="w-full px-2 py-1.5 text-sm border border-slate-200 rounded focus:border-woot-500 outline-none resize-none"
                  placeholder="Notas sobre esta tarefa..."
                />
              </div>

              <!-- Save Button -->
              <button
                @click="addToKanban"
                :disabled="isLoading"
                class="w-full px-3 py-2 bg-woot-600 text-white rounded-lg text-sm font-semibold hover:bg-woot-700 transition-colors disabled:opacity-50"
              >
                Salvar Alterações
              </button>
            </div>

            <!-- Remove Button -->
            <button
              @click="removeFromKanban"
              class="w-full px-3 py-1.5 text-red-600 hover:bg-red-50 rounded text-sm font-medium transition-colors"
            >
              <i class="i-lucide-trash-2 mr-1" />
              Remover do Kanban
            </button>
          </div>
        </div>

        <!-- Add to Kanban -->
        <div v-else class="space-y-3">
          <p class="text-xs text-slate-500">
            Esta conversa não está no Kanban ainda
          </p>

          <!-- Stage Selection -->
          <div>
            <label class="block text-xs font-semibold text-slate-600 mb-2 uppercase">
              Estágio Inicial
            </label>
            <select
              v-model="currentStage"
              class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:border-woot-500 outline-none"
            >
              <option value="">Selecione um estágio...</option>
              <option
                v-for="stage in currentBoardStages"
                :key="stage.id"
                :value="stage.id"
              >
                {{ stage.name }}
              </option>
            </select>
          </div>

          <!-- Add Button -->
          <button
            @click="addToKanban"
            :disabled="!currentStage || isLoading"
            class="w-full px-4 py-2 bg-woot-600 text-white rounded-lg font-semibold hover:bg-woot-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <i class="i-lucide-plus mr-2" />
            Adicionar ao Kanban
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
