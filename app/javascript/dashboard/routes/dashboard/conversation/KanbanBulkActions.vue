<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

const props = defineProps({
  selectedItems: { type: Array, required: true },
  stages: { type: Array, required: true },
  currentBoard: { type: Object, required: true },
});

const emit = defineEmits(['bulkUpdate', 'close']);

const { t } = useI18n();
const store = useStore();

const action = ref('');
const targetStage = ref('');
const targetAssignee = ref('');
const targetPriority = ref('');

const agents = computed(() => store.getters['agents/getAgents'] || []);

const canExecute = computed(() => {
  if (!action.value) return false;
  
  if (action.value === 'move' && !targetStage.value) return false;
  if (action.value === 'assign' && !targetAssignee.value) return false;
  if (action.value === 'priority' && !targetPriority.value) return false;
  
  return true;
});

const executeBulkAction = async () => {
  if (!canExecute.value) return;
  
  emit('bulkUpdate', {
    action: action.value,
    stage: targetStage.value,
    assignee: targetAssignee.value,
    priority: targetPriority.value,
  });
};
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-end justify-center sm:items-center bg-slate-900/50 backdrop-blur-sm">
    <div class="w-full max-w-lg bg-white rounded-t-2xl sm:rounded-2xl shadow-2xl border border-slate-200 overflow-hidden">
      <!-- Header -->
      <div class="flex items-center justify-between p-6 border-b border-slate-100">
        <div>
          <h3 class="text-lg font-bold text-slate-900">
            Ações em Massa
          </h3>
          <p class="text-sm text-slate-500 mt-1">
            {{ selectedItems.length }} tarefa(s) selecionada(s)
          </p>
        </div>
        <button
          @click="$emit('close')"
          class="p-2 hover:bg-slate-100 rounded-full transition-colors text-slate-400 hover:text-slate-600"
        >
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <!-- Content -->
      <div class="p-6 space-y-4">
        <!-- Selecionar ação -->
        <div>
          <label class="block text-sm font-semibold text-slate-700 mb-2">
            Selecione a ação
          </label>
          <select
            v-model="action"
            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
          >
            <option value="">Escolha uma ação...</option>
            <option value="move">Mover para estágio</option>
            <option value="assign">Atribuir agente</option>
            <option value="priority">Alterar prioridade</option>
            <option value="archive">Arquivar tarefas</option>
            <option value="delete">Excluir tarefas</option>
          </select>
        </div>

        <!-- Mover para estágio -->
        <div v-if="action === 'move'" class="pt-2">
          <label class="block text-sm font-semibold text-slate-700 mb-2">
            Estágio de destino
          </label>
          <select
            v-model="targetStage"
            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
          >
            <option value="">Selecione um estágio...</option>
            <option
              v-for="stage in stages"
              :key="stage.stage"
              :value="stage.stage"
            >
              {{ stage.title }}
            </option>
          </select>
        </div>

        <!-- Atribuir agente -->
        <div v-if="action === 'assign'" class="pt-2">
          <label class="block text-sm font-semibold text-slate-700 mb-2">
            Agente
          </label>
          <select
            v-model="targetAssignee"
            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
          >
            <option value="">Selecione um agente...</option>
            <option value="unassign">Remover atribuição</option>
            <option
              v-for="agent in agents"
              :key="agent.id"
              :value="agent.id"
            >
              {{ agent.name }}
            </option>
          </select>
        </div>

        <!-- Alterar prioridade -->
        <div v-if="action === 'priority'" class="pt-2">
          <label class="block text-sm font-semibold text-slate-700 mb-2">
            Prioridade
          </label>
          <select
            v-model="targetPriority"
            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
          >
            <option value="">Selecione uma prioridade...</option>
            <option value="low">Baixa</option>
            <option value="medium">Média</option>
            <option value="high">Alta</option>
            <option value="urgent">Urgente</option>
          </select>
        </div>

        <!-- Warning para ações destrutivas -->
        <div v-if="action === 'delete' || action === 'archive'" class="bg-red-50 border border-red-200 rounded-lg p-4">
          <div class="flex items-start gap-3">
            <i class="i-lucide-alert-triangle text-red-500 text-xl flex-shrink-0 mt-0.5" />
            <div>
              <p class="text-sm font-semibold text-red-800 mb-1">
                Atenção!
              </p>
              <p class="text-xs text-red-700">
                {{ action === 'delete' 
                  ? 'Esta ação irá remover permanentemente as tarefas selecionadas do Kanban.' 
                  : 'As tarefas serão arquivadas e poderão ser restauradas posteriormente.' 
                }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-end gap-3 p-6 border-t border-slate-100">
        <button
          @click="$emit('close')"
          class="px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100 rounded-lg transition-colors"
        >
          Cancelar
        </button>
        <button
          @click="executeBulkAction"
          :disabled="!canExecute"
          class="px-4 py-2 text-sm font-semibold bg-woot-600 text-white rounded-lg hover:bg-woot-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          :class="{ 'bg-red-600 hover:bg-red-700': action === 'delete' }"
        >
          <span v-if="action === 'delete'">Excluir Tarefas</span>
          <span v-else-if="action === 'archive'">Arquivar Tarefas</span>
          <span v-else>Aplicar Ação</span>
        </button>
      </div>
    </div>
  </div>
</template>
