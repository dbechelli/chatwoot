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

// Configuração dos estágios do pipeline de vendas
const salesStages = ref([
  {
    stage: 'lead',
    title: t('KANBAN.STAGES.LEAD'),
    color: '#3b82f6',
    wipLimit: null,
  },
  {
    stage: 'qualified',
    title: t('KANBAN.STAGES.QUALIFIED'),
    color: '#8b5cf6',
    wipLimit: 20,
  },
  {
    stage: 'proposal',
    title: t('KANBAN.STAGES.PROPOSAL'),
    color: '#f59e0b',
    wipLimit: 15,
  },
  {
    stage: 'negotiation',
    title: t('KANBAN.STAGES.NEGOTIATION'),
    color: '#ec4899',
    wipLimit: 10,
  },
  {
    stage: 'won',
    title: t('KANBAN.STAGES.WON'),
    color: '#10b981',
    wipLimit: null,
  },
  {
    stage: 'lost',
    title: t('KANBAN.STAGES.LOST'),
    color: '#ef4444',
    wipLimit: null,
  },
]);

// Getters
const allConversations = computed(
  () => store.getters.getAllConversations || []
);

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);

// Agrupar conversas por estágio
const conversationsByStage = computed(() => {
  const grouped = {};

  salesStages.value.forEach(stage => {
    let filtered = allConversations.value.filter(
      conv => conv.custom_attributes?.sales_stage === stage.stage
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
    // Atualizar custom attribute
    const customAttributes = {
      ...conversation.custom_attributes,
      sales_stage: newStage,
    };

    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes,
    });

    useAlert(t('KANBAN.STAGE_UPDATED'));
  } catch {
    useAlert(t('KANBAN.UPDATE_ERROR'));
    // Recarregar para reverter o drag & drop
    fetchConversations();
  }
};

const handleCardClick = conversation => {
  // Navegar para a conversa
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
onMounted(() => {
  fetchConversations();

  // Buscar inboxes e agentes
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
});

// Watchers
watch([selectedInbox, selectedAssignee], () => {
  // Os filtros são reativos, não precisa refetch
});
</script>

<template>
  <div class="flex h-screen flex-col bg-n-slate-1">
    <!-- Header -->
    <div class="flex flex-col gap-4 border-b border-n-slate-6 bg-white p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <i class="i-lucide-kanban-square text-2xl text-n-brand" />
          <h1 class="text-2xl font-bold text-n-slate-12">
            {{ t('KANBAN.TITLE') }}
          </h1>
        </div>

        <div class="flex items-center gap-2">
          <!-- Toggle Metrics -->
          <button
            class="inline-flex items-center gap-2 rounded-lg border border-n-slate-6 px-3 py-2 text-sm font-medium text-n-slate-12 transition-colors hover:bg-n-slate-3"
            @click="toggleMetrics"
          >
            <i :class="showMetrics ? 'i-lucide-eye-off' : 'i-lucide-eye'" />
            {{
              showMetrics ? t('KANBAN.HIDE_METRICS') : t('KANBAN.SHOW_METRICS')
            }}
          </button>

          <!-- Refresh -->
          <button
            class="inline-flex items-center gap-2 rounded-lg border border-n-slate-6 px-3 py-2 text-sm font-medium text-n-slate-12 transition-colors hover:bg-n-slate-3"
            :disabled="isLoading"
            @click="handleRefresh"
          >
            <i
              class="i-lucide-refresh-cw"
              :class="{ 'animate-spin': isLoading }"
            />
            {{ t('KANBAN.REFRESH') }}
          </button>
        </div>
      </div>

      <!-- Filtros -->
      <div class="flex items-center gap-4">
        <!-- Filtro de Inbox -->
        <div class="flex items-center gap-2">
          <label class="text-sm font-medium text-n-slate-11">
            {{ t('KANBAN.FILTERS.INBOX') }}:
          </label>
          <select
            v-model="selectedInbox"
            class="rounded-lg border border-n-slate-6 px-3 py-1.5 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
          >
            <option :value="null">{{ t('KANBAN.FILTERS.ALL_INBOXES') }}</option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </div>

        <!-- Filtro de Assignee -->
        <div class="flex items-center gap-2">
          <label class="text-sm font-medium text-n-slate-11">
            {{ t('KANBAN.FILTERS.ASSIGNEE') }}:
          </label>
          <select
            v-model="selectedAssignee"
            class="rounded-lg border border-n-slate-6 px-3 py-1.5 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
          >
            <option value="all">{{ t('KANBAN.FILTERS.ALL_AGENTS') }}</option>
            <option value="me">{{ t('KANBAN.FILTERS.MY_DEALS') }}</option>
            <option value="unassigned">
              {{ t('KANBAN.FILTERS.UNASSIGNED') }}
            </option>
          </select>
        </div>
      </div>
    </div>

    <!-- Metrics -->
    <div v-if="showMetrics" class="border-b border-n-slate-6 bg-n-slate-2 p-4">
      <KanbanMetrics
        :conversations="filteredConversations"
        :stages="salesStages"
      />
    </div>

    <!-- Kanban Board -->
    <div class="flex-1 overflow-x-auto p-4">
      <div
        v-if="isLoading && !allConversations.length"
        class="flex h-full items-center justify-center"
      >
        <div class="flex flex-col items-center gap-4">
          <i class="i-lucide-loader-2 animate-spin text-4xl text-n-brand" />
          <p class="text-sm text-n-slate-11">{{ t('KANBAN.LOADING') }}</p>
        </div>
      </div>

      <div v-else class="flex min-w-fit gap-4">
        <div v-for="stage in salesStages" :key="stage.stage" class="w-80">
          <KanbanColumn
            :stage="stage.stage"
            :title="stage.title"
            :color="stage.color"
            :conversations="conversationsByStage[stage.stage] || []"
            :wip-limit="stage.wipLimit"
            @stage-change="handleStageChange"
            @card-click="handleCardClick"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Custom scrollbar */
::-webkit-scrollbar {
  height: 10px;
  width: 10px;
}

::-webkit-scrollbar-track {
  background: var(--color-background);
}

::-webkit-scrollbar-thumb {
  background: var(--color-border);
  border-radius: 5px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--color-border-dark);
}
</style>
