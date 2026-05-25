<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Button from 'dashboard/components-next/button/Button.vue';

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
  <div class="fixed inset-0 z-50 flex items-end justify-center bg-n-slate-12/40 backdrop-blur-sm sm:items-center">
    <div class="w-full max-w-lg overflow-hidden rounded-t-2xl border border-n-weak bg-n-surface-1 shadow-2xl sm:rounded-2xl">
      <div class="flex items-center justify-between border-b border-n-weak px-6 py-5">
        <div>
          <h3 class="text-lg font-medium text-n-slate-12">
            Ações em Massa
          </h3>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ selectedItems.length }} tarefa(s) selecionada(s)
          </p>
        </div>
        <button
          @click="$emit('close')"
          class="rounded-full p-2 text-n-slate-10 transition-colors hover:bg-n-slate-2 hover:text-n-slate-12"
        >
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <div class="space-y-4 p-6">
        <div>
          <label class="mb-2 block text-sm font-medium text-n-slate-12">
            Selecione a ação
          </label>
          <select
            v-model="action"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
          >
            <option value="">Escolha uma ação...</option>
            <option value="move">Mover para estágio</option>
            <option value="assign">Atribuir agente</option>
            <option value="priority">Alterar prioridade</option>
            <option value="archive">Arquivar tarefas</option>
            <option value="delete">Excluir tarefas</option>
          </select>
        </div>

        <div v-if="action === 'move'" class="pt-2">
          <label class="mb-2 block text-sm font-medium text-n-slate-12">
            Estágio de destino
          </label>
          <select
            v-model="targetStage"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
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

        <div v-if="action === 'assign'" class="pt-2">
          <label class="mb-2 block text-sm font-medium text-n-slate-12">
            Agente
          </label>
          <select
            v-model="targetAssignee"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
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

        <div v-if="action === 'priority'" class="pt-2">
          <label class="mb-2 block text-sm font-medium text-n-slate-12">
            Prioridade
          </label>
          <select
            v-model="targetPriority"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
          >
            <option value="">Selecione uma prioridade...</option>
            <option value="low">Baixa</option>
            <option value="medium">Média</option>
            <option value="high">Alta</option>
            <option value="urgent">Urgente</option>
          </select>
        </div>

        <div v-if="action === 'delete' || action === 'archive'" class="rounded-2xl border border-n-ruby-6/40 bg-n-ruby-3 p-4">
          <div class="flex items-start gap-3">
            <i class="i-lucide-alert-triangle mt-0.5 shrink-0 text-xl text-n-ruby-11" />
            <div>
              <p class="mb-1 text-sm font-medium text-n-ruby-11">
                Atenção!
              </p>
              <p class="text-xs text-n-ruby-11">
                {{ action === 'delete' 
                  ? 'Esta ação irá remover permanentemente as tarefas selecionadas do Kanban.' 
                  : 'As tarefas serão arquivadas e poderão ser restauradas posteriormente.' 
                }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-end gap-3 border-t border-n-weak p-6">
        <Button @click="$emit('close')" slate outline label="Cancelar" />
        <Button
          @click="executeBulkAction"
          :disabled="!canExecute"
          :ruby="action === 'delete'"
          :blue="action !== 'delete'"
          solid
          :label="action === 'delete' ? 'Excluir Tarefas' : action === 'archive' ? 'Arquivar Tarefas' : 'Aplicar Ação'"
        />
      </div>
    </div>
  </div>
</template>
