<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

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
  <div class="flex h-full flex-col border-l border-n-weak bg-n-surface-1">
    <div class="flex items-center justify-between border-b border-n-weak px-4 py-4">
      <div class="flex items-center gap-2">
        <i class="i-lucide-kanban-square text-xl text-n-blue-11" />
        <h3 class="font-medium text-n-slate-12">Kanban</h3>
      </div>
      <button
        v-if="isInKanban"
        @click="isExpanded = !isExpanded"
        class="rounded-lg p-1 text-n-slate-10 transition-colors hover:bg-n-slate-2"
      >
        <i :class="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'" class="text-n-slate-10" />
      </button>
    </div>

    <div class="flex-1 space-y-4 overflow-y-auto p-4">
      <div v-if="availableBoards.length === 0" class="py-8 text-center">
        <i class="i-lucide-kanban-square mb-2 text-4xl text-n-slate-8" />
        <p class="text-sm text-n-slate-11">Nenhum quadro disponível</p>
      </div>

      <div v-else>
        <div>
          <label class="mb-2 block text-xs font-medium uppercase tracking-wide text-n-slate-10">
            Quadro
          </label>
          <select
            v-model="selectedBoard"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
          >
            <option v-for="board in availableBoards" :key="board.id" :value="board">
              {{ board.name }}
            </option>
          </select>
        </div>

        <div v-if="isInKanban" class="rounded-2xl border border-n-brand/20 bg-n-brand/5 p-3">
          <div class="mb-2 flex items-center gap-2">
            <i class="i-lucide-check-circle text-n-blue-11" />
            <span class="text-xs font-medium uppercase tracking-wide text-n-blue-11">No Kanban</span>
          </div>
          
          <div class="space-y-3">
            <div>
              <label class="mb-1 block text-xs font-medium text-n-slate-11">
                Estágio Atual
              </label>
              <select
                v-model="currentStage"
                @change="updateStage(currentStage)"
                :disabled="isLoading"
                class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
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

            <div v-if="isExpanded" class="space-y-3 border-t border-n-brand/20 pt-2">
              <div>
                <label class="mb-1 block text-xs font-medium text-n-slate-11">
                  Prioridade
                </label>
                <select
                  v-model="priority"
                  class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                >
                  <option value="low">Baixa</option>
                  <option value="medium">Média</option>
                  <option value="high">Alta</option>
                  <option value="urgent">Urgente</option>
                </select>
              </div>

              <div v-if="selectedBoard?.valueAttributeKey">
                <label class="mb-1 block text-xs font-medium text-n-slate-11">
                  Valor
                </label>
                <input
                  v-model.number="dealValue"
                  type="number"
                  min="0"
                  step="0.01"
                  class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                  placeholder="R$ 0,00"
                />
              </div>

              <div>
                <label class="mb-1 block text-xs font-medium text-n-slate-11">
                  Data de Início
                </label>
                <input
                  v-model="startDate"
                  type="date"
                  class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                />
              </div>

              <div>
                <label class="mb-1 block text-xs font-medium text-n-slate-11">
                  Data de Vencimento
                </label>
                <input
                  v-model="dueDate"
                  type="date"
                  class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                />
              </div>

              <div>
                <label class="mb-1 block text-xs font-medium text-n-slate-11">
                  Notas
                </label>
                <textarea
                  v-model="notes"
                  rows="3"
                  class="w-full resize-none rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                  placeholder="Notas sobre esta tarefa..."
                />
              </div>

              <Button
                @click="addToKanban"
                :disabled="isLoading"
                blue
                solid
                class="w-full"
                label="Salvar Alterações"
              />
            </div>

            <Button
              @click="removeFromKanban"
              ruby
              ghost
              icon="i-lucide-trash-2"
              class="w-full justify-start"
              label="Remover do Kanban"
            />
          </div>
        </div>

        <div v-else class="space-y-3">
          <p class="text-xs text-n-slate-11">
            Esta conversa não está no Kanban ainda
          </p>

          <div>
            <label class="mb-2 block text-xs font-medium uppercase tracking-wide text-n-slate-10">
              Estágio Inicial
            </label>
            <select
              v-model="currentStage"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
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

          <Button
            @click="addToKanban"
            :disabled="!currentStage || isLoading"
            blue
            solid
            icon="i-lucide-plus"
            class="w-full"
            label="Adicionar ao Kanban"
          />
        </div>
      </div>
    </div>
  </div>
</template>
