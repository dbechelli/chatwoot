<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import KanbanColumn from 'dashboard/components/KanbanBoard/KanbanColumn.vue';
import KanbanMetrics from 'dashboard/components/KanbanBoard/KanbanMetrics.vue';
import wootConstants from 'dashboard/constants/globals';
import { useAlert } from 'dashboard/composables';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

// Estado local
const isLoading = ref(false);
const selectedInbox = ref(null);
const selectedAssignee = ref('all');
const showMetrics = ref(true);

// Kanban configuration
const kanbanConfig = ref(null);
const selectedBoardId = ref(null);
const isLoadingConfig = ref(true);

// Fallback stages (se não houver config do backend)
const defaultStages = [
  {
    id: 'novo_contato',
    name: t('KANBAN.STAGES.NEW_CONTACT'),
    color: '#3b82f6',
    wipLimit: null,
  },
  {
    id: 'qualificacao',
    name: t('KANBAN.STAGES.QUALIFICATION'),
    color: '#8b5cf6',
    wipLimit: 30,
  },
  {
    id: 'agendamento_pendente',
    name: t('KANBAN.STAGES.PENDING_APPOINTMENT'),
    color: '#f59e0b',
    wipLimit: 20,
  },
  {
    id: 'agendado',
    name: t('KANBAN.STAGES.SCHEDULED'),
    color: '#10b981',
    wipLimit: null,
  },
  {
    id: 'pos_consulta',
    name: t('KANBAN.STAGES.POST_CONSULT'),
    color: '#ec4899',
    wipLimit: 15,
  },
  {
    id: 'paciente_ativo',
    name: t('KANBAN.STAGES.ACTIVE_PATIENT'),
    color: '#6366f1',
    wipLimit: null,
  },
  {
    id: 'inativo',
    name: t('KANBAN.STAGES.INACTIVE'),
    color: '#64748b',
    wipLimit: null,
  },
];

// Current board computed
const currentBoard = computed(() => {
  if (!kanbanConfig.value || !kanbanConfig.value.boards) return null;
  return kanbanConfig.value.boards.find(b => b.id === selectedBoardId.value);
});

// Sales stages from current board or fallback
const salesStages = computed(() => {
  if (currentBoard.value && currentBoard.value.stages) {
    return currentBoard.value.stages.map(stage => ({
      stage: stage.id,
      title: stage.name,
      color: stage.color,
      wipLimit: stage.wipLimit,
    }));
  }
  return defaultStages.map(s => ({
    stage: s.id,
    title: s.name,
    color: s.color,
    wipLimit: s.wipLimit,
  }));
});

// Custom attribute key from current board
const customAttributeKey = computed(() => {
  return currentBoard.value?.customAttributeKey || 'sales_stage';
});

// Getters
const allConversations = computed(
  () => store.getters.getAllConversations || []
);

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);

// Agrupar conversas por estágio
const conversationsByStage = computed(() => {
  const grouped = {};
  const attrKey = customAttributeKey.value;

  salesStages.value.forEach(stage => {
    let filtered = allConversations.value.filter(
      conv => conv.custom_attributes?.[attrKey] === stage.stage
    );

    // Aplicar filtros de inbox
    if (selectedInbox.value) {
      filtered = filtered.filter(conv => conv.inbox_id === selectedInbox.value);
    }

    // Aplicar filtros de assignee
    if (selectedAssignee.value === 'me') {
      const currentUserId = store.getters.getCurrentUser.id;
      filtered = filtered.filter(
        conv => conv.meta?.assignee?.id === currentUserId
      );
    } else if (selectedAssignee.value === 'unassigned') {
      filtered = filtered.filter(conv => !conv.meta?.assignee);
    }

    grouped[stage.stage] = filtered;
  });

  return grouped;
});

// Todas as conversas filtradas (para métricas)
const filteredConversations = computed(() => {
  return Object.values(conversationsByStage.value).flat();
});

// Métodos
const loadKanbanConfig = async () => {
  isLoadingConfig.value = true;
  try {
    const accountId = store.getters.getCurrentAccountId;
    const response = await window.axios.get(
      `/api/v1/accounts/${accountId}/kanban_settings`
    );
    kanbanConfig.value = response.data;

    // Selecionar board da URL ou board padrão ou primeiro disponível
    if (kanbanConfig.value.boards && kanbanConfig.value.boards.length > 0) {
      const boardIdFromQuery = router.currentRoute.value.query.board;
      if (boardIdFromQuery) {
        const boardFromQuery = kanbanConfig.value.boards.find(
          b => b.id.toString() === boardIdFromQuery.toString()
        );
        selectedBoardId.value = boardFromQuery?.id || null;
      }

      if (!selectedBoardId.value) {
        const defaultBoard = kanbanConfig.value.boards.find(b => b.isDefault);
        selectedBoardId.value =
          defaultBoard?.id || kanbanConfig.value.boards[0].id;
      }
    }
  } catch (error) {
    // Se falhar, usar configuração padrão (fallback)
    kanbanConfig.value = { enabled: true, boards: [] };
  } finally {
    isLoadingConfig.value = false;
  }
};

const fetchConversations = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('fetchAllConversations', {
      status: wootConstants.STATUS_TYPE.ALL,
      assigneeType: wootConstants.ASSIGNEE_TYPE.ALL,
    });
  } catch {
    useAlert(t('KANBAN.FETCH_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const handleStageChange = async ({
  conversationId,
  newStage,
  conversation,
}) => {
  try {
    const attrKey = customAttributeKey.value;
    const customAttributes = {
      ...conversation.custom_attributes,
      [attrKey]: newStage,
    };

    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes,
    });

    useAlert(t('KANBAN.STAGE_UPDATED'));
  } catch {
    useAlert(t('KANBAN.UPDATE_ERROR'));
    fetchConversations();
  }
};

const handleCardClick = conversation => {
  router.push({
    name: 'inbox_conversation',
    params: {
      conversation_id: conversation.id,
    },
  });
};

const handleRefresh = () => {
  fetchConversations();
};

const toggleMetrics = () => {
  showMetrics.value = !showMetrics.value;
};

// Lifecycle
onMounted(async () => {
  await loadKanbanConfig();
  fetchConversations();
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
});

// Watchers
watch([selectedInbox, selectedAssignee], () => {
  // Filtros reativos
});
</script>

<template>
  <div class="flex h-full flex-col bg-[#f8fafc]">
    <header
      class="z-20 flex flex-col gap-4 border-b border-slate-200 bg-white p-4 shadow-sm"
    >
      <div
        class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
      >
        <div class="flex items-center gap-3">
          <div
            class="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-600 text-white shadow-md"
          >
            <i class="i-lucide-kanban-square text-2xl" />
          </div>
          <div>
            <h1 class="text-xl font-bold text-slate-900 leading-tight">
              {{ currentBoard?.name || t('KANBAN.TITLE') }}
            </h1>
            <span
              class="text-xs font-medium text-slate-500 uppercase tracking-wider"
            >
              {{ currentBoard?.description || 'Gestão de Funil' }}
            </span>
          </div>
        </div>

        <div class="flex items-center gap-2 flex-wrap">
          <button
            class="inline-flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition-all hover:bg-slate-50 hover:border-slate-300 active:scale-95 shadow-sm"
            @click="toggleMetrics"
          >
            <i
              class="text-lg"
              :class="showMetrics ? 'i-lucide-eye-off' : 'i-lucide-eye'"
            />
            <span class="hidden sm:inline">{{
              showMetrics ? t('KANBAN.HIDE_METRICS') : t('KANBAN.SHOW_METRICS')
            }}</span>
          </button>

          <button
            class="inline-flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-semibold text-white transition-all hover:bg-slate-800 active:scale-95 disabled:opacity-50 shadow-sm shadow-slate-200"
            :disabled="isLoading"
            @click="handleRefresh"
          >
            <i
              class="text-lg i-lucide-refresh-cw"
              :class="{ 'animate-spin': isLoading }"
            />
            <span class="hidden sm:inline">{{ t('KANBAN.REFRESH') }}</span>
          </button>
        </div>
      </div>

      <div
        class="flex flex-col gap-3 md:flex-row md:items-center md:gap-6 pt-1"
      >
        <!-- Seletor de Board (se houver múltiplos) -->
        <div
          v-if="
            kanbanConfig &&
            kanbanConfig.boards &&
            kanbanConfig.boards.length > 1
          "
          class="flex items-center gap-3"
        >
          <label
            class="text-xs font-bold text-slate-400 uppercase tracking-tight"
          >
            {{ t('KANBAN.BOARD') }}
          </label>
          <select
            v-model="selectedBoardId"
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-blue-500 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
          >
            <option
              v-for="board in kanbanConfig.boards"
              :key="board.id"
              :value="board.id"
            >
              {{ board.name }}
            </option>
          </select>
        </div>

        <div class="flex items-center gap-3">
          <label
            class="text-xs font-bold text-slate-400 uppercase tracking-tight"
          >
            {{ t('KANBAN.FILTERS.INBOX') }}
          </label>
          <select
            v-model="selectedInbox"
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-blue-500 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
          >
            <option :value="null">{{ t('KANBAN.FILTERS.ALL_INBOXES') }}</option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </div>

        <div class="flex items-center gap-3">
          <label
            class="text-xs font-bold text-slate-400 uppercase tracking-tight"
          >
            {{ t('KANBAN.FILTERS.ASSIGNEE') }}
          </label>
          <select
            v-model="selectedAssignee"
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-blue-500 focus:ring-2 focus:ring-blue-100 outline-none transition-all"
          >
            <option value="all">{{ t('KANBAN.FILTERS.ALL_AGENTS') }}</option>
            <option value="me">{{ t('KANBAN.FILTERS.MY_DEALS') }}</option>
            <option value="unassigned">
              {{ t('KANBAN.FILTERS.UNASSIGNED') }}
            </option>
          </select>
        </div>
      </div>
    </header>

    <Transition name="fade">
      <div v-if="showMetrics" class="border-b border-slate-200 bg-white/50 p-4">
        <KanbanMetrics
          :conversations="filteredConversations"
          :stages="salesStages"
        />
      </div>
    </Transition>

    <main class="flex-1 overflow-x-auto overflow-y-hidden custom-scrollbar">
      <div
        v-if="isLoading && !allConversations.length"
        class="flex h-full items-center justify-center"
      >
        <div class="flex flex-col items-center gap-4">
          <i class="i-lucide-loader-2 animate-spin text-5xl text-blue-600" />
          <p class="text-sm font-semibold text-slate-500">
            {{ t('KANBAN.LOADING') }}
          </p>
        </div>
      </div>

      <div
        v-else
        class="inline-flex h-full items-start gap-4 p-4 md:p-6 min-w-full"
      >
        <div
          v-for="stage in salesStages"
          :key="stage.stage"
          class="flex h-full w-80 flex-shrink-0 flex-col"
        >
          <KanbanColumn
            :stage="stage.stage"
            :title="stage.title"
            :color="stage.color"
            :conversations="conversationsByStage[stage.stage] || []"
            :wip-limit="stage.wipLimit"
            class="shadow-sm border border-slate-200 rounded-xl"
            @stage-change="handleStageChange"
            @card-click="handleCardClick"
          />
        </div>
        <div class="w-4 flex-shrink-0" />
      </div>
    </main>
  </div>
</template>

<style scoped>
/* Scrollbar customizada e moderna */
.custom-scrollbar::-webkit-scrollbar {
  height: 8px; /* Altura do scroll horizontal */
  width: 8px;
}

.custom-scrollbar::-webkit-scrollbar-track {
  background: #f1f5f9; /* slate-100 */
  border-radius: 10px;
}

.custom-scrollbar::-webkit-scrollbar-thumb {
  background: #cbd5e1; /* slate-300 */
  border-radius: 10px;
  border: 2px solid #f1f5f9;
}

.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: #94a3b8; /* slate-400 */
}

/* Transição suave para métricas */
.fade-enter-active,
.fade-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}

/* Garante que o container ocupe a altura disponível */
main {
  display: flex;
  flex-direction: column;
}
</style>
