<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import KanbanColumn from 'dashboard/components/KanbanBoard/KanbanColumn.vue';
import KanbanMetrics from 'dashboard/components/KanbanBoard/KanbanMetrics.vue';
import KanbanListView from './KanbanListView.vue';
import KanbanCalendar from './KanbanCalendar.vue';
import KanbanHelpModal from './KanbanHelpModal.vue';
import KanbanItemModal from './KanbanItemModal.vue';
import KanbanContextMenu from './KanbanContextMenu.vue';
import KanbanBulkActions from './KanbanBulkActions.vue';
import Modal from 'dashboard/components/Modal.vue';
import wootConstants from 'dashboard/constants/globals';
import { useAlert } from 'dashboard/composables';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

// Estado local
const isLoading = ref(false);
const showHelpModal = ref(false);
const showItemModal = ref(false);
const editingItem = ref(null); // Item being edited
const selectedStageId = ref('');
const selectedInbox = ref(null);
const selectedAssignee = ref('all');
const statusFilter = ref(wootConstants.STATUS_TYPE.OPEN);
const groupBy = ref('none'); // 'none', 'priority', 'assignee'
const showMetrics = ref(true);
const viewMode = ref('board'); // 'board' or 'list'
const selectedItems = ref([]); // Para ações em massa
const showBulkActions = ref(false);

// Context Menu State
const showContextMenu = ref(false);
const contextMenuX = ref(0);
const contextMenuY = ref(0);
const contextMenuItem = ref(null);

// Kanban configuration
const kanbanConfig = ref(null);
const selectedBoardId = ref(null);
const isLoadingConfig = ref(true);

// Fallback stages (se não houver config do backend)
const defaultStages = [];

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
  return [];
});

// Custom attribute key from current board
const customAttributeKey = computed(() => {
  return currentBoard.value?.customAttributeKey || 'sales_stage';
});

// Visible attributes from current board
const visibleAttributes = computed(() => {
  return currentBoard.value?.visible_attributes || [];
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

// Swimlane Groups
const swimlaneGroups = computed(() => {
  if (groupBy.value === 'priority') {
    return [
      { id: 'urgent', name: 'Urgente', value: 'urgent' },
      { id: 'high', name: 'Alta', value: 'high' },
      { id: 'medium', name: 'Média', value: 'medium' },
      { id: 'low', name: 'Baixa', value: 'low' },
      { id: null, name: 'Sem Prioridade', value: null },
    ];
  } else if (groupBy.value === 'assignee') {
    const agents = store.getters['agents/getAgents'] || [];
    const groups = agents.map(agent => ({
      id: agent.id,
      name: agent.name,
      value: agent.id
    }));
    groups.push({ id: 0, name: 'Não Atribuído', value: 0 }); // 0 represents unassigned in API usually
    return groups;
  }
  return [];
});

const getSwimlaneConversations = (stageId, groupId) => {
  const stageConvos = conversationsByStage.value[stageId] || [];
  
  if (groupBy.value === 'priority') {
    return stageConvos.filter(c => c.priority === groupId);
  } else if (groupBy.value === 'assignee') {
    if (groupId === 0) {
      return stageConvos.filter(c => !c.meta?.assignee?.id);
    }
    return stageConvos.filter(c => c.meta?.assignee?.id === groupId);
  }
  return [];
};

// Métodos
const loadKanbanConfig = async () => {
  isLoadingConfig.value = true;
  try {
    const accountId = store.getters.getCurrentAccountId;
    if (!accountId) return;
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
      status: statusFilter.value,
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
  groupUpdate // { type: 'priority'|'assignee', value: ... }
}) => {
  try {
    const attrKey = customAttributeKey.value;
    const customAttributes = {
      ...conversation.custom_attributes,
      [attrKey]: newStage,
    };

    // If moved between swimlanes
    if (groupUpdate) {
      if (groupUpdate.type === 'priority') {
        await store.dispatch('updateConversation', {
          conversationId,
          priority: groupUpdate.value
        });
      } else if (groupUpdate.type === 'assignee') {
        await store.dispatch('assignAgent', {
          conversationId,
          agentId: groupUpdate.value
        });
      }
    }

    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes,
    });

    // Webhook Trigger
    if (currentBoard.value?.webhook_url) {
      try {
        await window.axios.post(currentBoard.value.webhook_url, {
          event: 'kanban_card_moved',
          board_id: currentBoard.value.id,
          conversation_id: conversationId,
          new_stage: newStage,
          previous_stage: conversation.custom_attributes?.[attrKey],
          item: {
            title: conversation.custom_attributes?.kanban_title,
            value: conversation.custom_attributes?.deal_value,
            priority: conversation.priority,
            assignee: conversation.meta?.assignee,
            contact: conversation.meta?.sender,
          },
          timestamp: new Date().toISOString(),
        });
      } catch (webhookError) {
        console.error('Webhook trigger failed:', webhookError);
        // Don't block the UI flow if webhook fails
      }
    }

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

const openAddItemModal = (stageId = '') => {
  editingItem.value = null;
  selectedStageId.value = stageId;
  showItemModal.value = true;
};

const handleItemSaved = () => {
  fetchConversations();
  useAlert(t('KANBAN.ITEM_SAVED') || 'Item salvo com sucesso');
};

const handleCardContextmenu = (payload) => {
  // Ensure payload is valid
  if (!payload || !payload.event || !payload.conversation) {
    console.warn('Invalid context menu payload', payload);
    return;
  }
  const { event, conversation } = payload;
  contextMenuX.value = event.clientX;
  contextMenuY.value = event.clientY;
  contextMenuItem.value = conversation;
  showContextMenu.value = true;
};

const handleContextMenuAction = async ({ action, item }) => {
  if (action === 'edit') {
    editingItem.value = item;
    selectedStageId.value = item.custom_attributes?.[customAttributeKey.value];
    showItemModal.value = true;
  } else if (action === 'view_contact') {
    if (item.meta?.sender?.id) {
      router.push({ name: 'contacts_edit', params: { contactId: item.meta.sender.id, accountId: store.getters.getCurrentAccountId } });
    }
  } else if (action === 'open_conversation') {
    router.push({ name: 'inbox_conversation', params: { inbox_id: item.inbox_id, conversation_id: item.id } });
  } else if (action === 'delete') {
    try {
      const attrKey = customAttributeKey.value;
      const customAttributes = {
        ...item.custom_attributes,
        [attrKey]: null, // Clear the stage to remove from board
      };

      await store.dispatch('updateCustomAttributes', {
        conversationId: item.id,
        customAttributes,
      });
      
      useAlert(t('KANBAN.ITEM_REMOVED') || 'Item removido do Kanban');
      fetchConversations();
    } catch (error) {
      useAlert(t('KANBAN.UPDATE_ERROR'));
    }
  }
};

const toggleMetrics = () => {
  showMetrics.value = !showMetrics.value;
};

const toggleViewMode = () => {
  viewMode.value = viewMode.value === 'board' ? 'list' : 'board';
  

const handleBulkUpdate = async (bulkData) => {
  try {
    const { action, stage, assignee, priority } = bulkData;
    
    for (const itemId of selectedItems.value) {
      const conversation = allConversations.value.find(c => c.id === itemId);
      if (!conversation) continue;
      
      if (action === 'move' && stage) {
        const attrKey = customAttributeKey.value;
        const customAttributes = {
          ...conversation.custom_attributes,
          [attrKey]: stage,
        };
        await store.dispatch('updateCustomAttributes', {
          conversationId: itemId,
          customAttributes,
        });
      } else if (action === 'assign' && assignee) {
        if (assignee === 'unassign') {
          await store.dispatch('assignAgent', {
            conversationId: itemId,
            agentId: 0,
          });
        } else {
          await store.dispatch('assignAgent', {
            conversationId: itemId,
            agentId: parseInt(assignee),
          });
        }
      } else if (action === 'priority' && priority) {
        await store.dispatch('updateConversation', {
          conversationId: itemId,
          priority,
        });
      } else if (action === 'archive' || action === 'delete') {
        const attrKey = customAttributeKey.value;
        const customAttributes = {
          ...conversation.custom_attributes,
          [attrKey]: action === 'archive' ? 'archived' : null,
        };
        await store.dispatch('updateCustomAttributes', {
          conversationId: itemId,
          customAttributes,
        });
      }
    }
    
    useAlert(`${selectedItems.value.length} tarefa(s) atualizada(s) com sucesso`);
    showBulkActions.value = false;
    selectedItems.value = [];
    await fetchConversations();
  } catch (error) {
    useAlert('Erro ao executar ação em massa');
  }
};

// Saved Views (Smart Views)
const showSaveViewModal = ref(false);
const newViewName = ref('');

const currentUser = computed(() => store.getters.getCurrentUser);
const uiSettings = computed(() => currentUser.value.ui_settings || {});
const savedViews = computed(() => {
  const views = uiSettings.value.kanban_views || [];
  return views.filter(v => v.board_id === (selectedBoardId.value || 'default'));
});

const saveCurrentView = async () => {
  if (!newViewName.value) return;

  const newView = {
    id: Date.now().toString(),
    name: newViewName.value,
    board_id: selectedBoardId.value || 'default',
    filters: {
      inbox: selectedInbox.value,
      assignee: selectedAssignee.value,
      status: statusFilter.value,
    }
  };

  const currentViews = uiSettings.value.kanban_views || [];
  const updatedViews = [...currentViews, newView];

  try {
    await store.dispatch('updateProfile', {
      ui_settings: {
        ...uiSettings.value,
        kanban_views: updatedViews
      }
    });
    useAlert('Filtro salvo com sucesso');
    showSaveViewModal.value = false;
    newViewName.value = '';
  } catch (error) {
    useAlert('Erro ao salvar filtro');
  }
};

const applyView = (view) => {
  if (view.filters) {
    selectedInbox.value = view.filters.inbox;
    selectedAssignee.value = view.filters.assignee;
    statusFilter.value = view.filters.status || 'open';
    useAlert(`Filtro "${view.name}" aplicado`);
  }
};

const deleteView = async (viewId) => {
  if(!confirm('Tem certeza que deseja excluir este filtro?')) return;

  const currentViews = uiSettings.value.kanban_views || [];
  const updatedViews = currentViews.filter(v => v.id !== viewId);

  try {
    await store.dispatch('updateProfile', {
      ui_settings: {
        ...uiSettings.value,
        kanban_views: updatedViews
      }
    });
    useAlert('Filtro removido');
  } catch (error) {
    useAlert('Erro ao remover filtro');
  }
};

// Lifecycle
onMounted(async () => {
  await loadKanbanConfig();
  fetchConversations();
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
  store.dispatch('attributes/get');
});

// Watchers
watch(statusFilter, () => {
  fetchConversations();
});

watch([selectedInbox, selectedAssignee], () => {
  // Filtros reativos
});
</script>

<template>
  <div class="flex h-full flex-col bg-[#f8fafc]">
    <header
      v-if="salesStages.length > 0"
      class="z-20 flex flex-col gap-4 border-b border-slate-200 bg-white p-4 shadow-sm"
    >
      <div
        class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
      >
        <div class="flex items-center gap-3">
          <div
            class="flex h-10 w-10 items-center justify-center rounded-lg bg-woot-600 text-white shadow-md"
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
           div class="flex items-center gap-1 bg-slate-100 rounded-lg p-1">
            <button
              class="inline-flex items-center gap-2 rounded-md px-3 py-1.5 text-sm font-semibold transition-all"
              :class="viewMode === 'board' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600 hover:text-slate-900'"
              @click="viewMode = 'board'"
            >
              <i class="i-lucide-kanban-square text-lg" />
              <span class="hidden sm:inline">Quadro</span>
            </button>
            <button
              class="inline-flex items-center gap-2 rounded-md px-3 py-1.5 text-sm font-semibold transition-all"
              :class="viewMode === 'list' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600 hover:text-slate-900'"
              @click="viewMode = 'list'"
            >
              <i class="i-lucide-list text-lg" />
              <span class="hidden sm:inline">Lista</span>
            </button>
            <button
              class="inline-flex items-center gap-2 rounded-md px-3 py-1.5 text-sm font-semibold transition-all"
              :class="viewMode === 'calendar' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600 hover:text-slate-900'"
              @click="viewMode = 'calendar'"
            >
              <i class="i-lucide-calendar text-lg" />
              <span class="hidden sm:inline">Calendário</span>
            </button>
            <button
              class="inline-flex items-center gap-2 rounded-md px-3 py-1.5 text-sm font-semibold transition-all"
              :class="viewMode === 'list' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600 hover:text-slate-900'"
              @click="viewMode = 'list'"
            >
              <i class="i-lucide-list text-lg" />
              <span class="hidden sm:inline">Lista</span>
            </button>
          </div>

          < </span>
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
            class="inline-flex items-center gap-2 rounded-lg bg-woot-600 px-4 py-2 text-sm font-semibold text-white transition-all hover:bg-woot-700 active:scale-95 shadow-sm shadow-woot-200"
            @click="openAddItemModal()"
          >
            <i class="i-lucide-plus" />
            <span class="hidden sm:inline">{{ t('KANBAN.MODAL.NEW_ITEM') }}</span>
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
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
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
            Agrupamento
          </label>
          <select
            v-model="groupBy"
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
          >
            <option value="none">Nenhum</option>
            <option value="priority">Prioridade</option>
            <option value="assignee">Agente</option>
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
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
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
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
          >
            <option value="all">{{ t('KANBAN.FILTERS.ALL_AGENTS') }}</option>
            <option value="me">{{ t('KANBAN.FILTERS.MY_DEALS') }}</option>
            <option value="unassigned">
              {{ t('KANBAN.FILTERS.UNASSIGNED') }}
            </option>
          </select>
        </div>

        <div class="flex items-center gap-3">
          <label
            class="text-xs font-bold text-slate-400 uppercase tracking-tight"
          >
            Status
          </label>
          <select
            v-model="statusFilter"
            class="min-w-[160px] rounded-md border border-slate-200 bg-slate-50 px-3 py-1.5 text-sm font-medium text-slate-700 focus:border-woot-500 focus:ring-2 focus:ring-woot-100 outline-none transition-all"
          >
            <option value="open">Abertos</option>
            <option value="resolved">Arquivados</option>
            <option value="all">Todos</option>
          </select>
        </div>

        <!-- Saved Views Controls -->
        <div class="flex items-center gap-2 border-l border-slate-200 pl-4 ml-2">
          <div class="relative group">
            <button class="flex items-center gap-2 px-3 py-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-sm font-medium text-slate-700">
               <i class="i-lucide-bookmark text-woot-600" />
               Vistas Salvas
               <i class="i-lucide-chevron-down text-xs" />
            </button>
            
            <div class="absolute right-0 top-full mt-1 w-64 bg-white rounded-lg shadow-lg border border-slate-100 hidden group-hover:block z-50 p-1">
              <div v-if="savedViews.length === 0" class="p-3 text-center text-xs text-slate-500">
                Nenhuma vista salva
              </div>
              
              <div v-else class="flex flex-col gap-1">
                <div v-for="view in savedViews" :key="view.id" class="flex items-center justify-between p-2 hover:bg-slate-50 rounded group/item">
                  <button @click="applyView(view)" class="text-sm text-slate-700 font-medium flex-1 text-left">
                    {{ view.name }}
                  </button>
                  <button @click="deleteView(view.id)" class="text-red-500 opacity-0 group-hover/item:opacity-100 hover:bg-red-50 p-1 rounded">
                    <i class="i-lucide-trash-2 text-xs" />
                  </button>
                </div>
              </div>
              
              <div class="border-t border-slate-100 mt-1 pt-1">
                 <button @click="showSaveViewModal = true" class="w-full text-left px-2 py-1.5 text-xs text-woot-600 hover:bg-woot-50 rounded font-medium flex items-center gap-1">
                   <i class="i-lucide-plus" />
                   Salvar Filtros Atuais
                 </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>

    <!-- Save View Modal -->
    <Modal :show="showSaveViewModal" :on-close="() => showSaveViewModal = false">
      <div class="w-full max-w-md p-6">
        <h3 class="text-lg font-bold text-slate-900 mb-4">Salvar Vista Atual</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">Nome da Vista</label>
            <input 
              v-model="newViewName" 
              type="text" 
              class="w-full border border-slate-300 rounded-md px-3 py-2 text-sm focus:ring-woot-500 focus:border-woot-500"
              placeholder="Ex: Tickets Alta Prioridade"
            >
          </div>
          <div class="bg-slate-50 p-3 rounded text-sm text-slate-600">
            <p class="font-medium mb-1">Filtros que serão salvos:</p>
            <ul class="list-disc list-inside text-xs space-y-1">
              <li>Inbox: {{ selectedInbox ? inboxes.find(i => i.id === selectedInbox)?.name : 'Todos' }}</li>
              <li>Agente: {{ selectedAssignee === 'me' ? 'Eu' : (selectedAssignee === 'all' ? 'Todos' : selectedAssignee) }}</li>
              <li>Status: {{ statusFilter }}</li>
            </ul>
          </div>
          <div class="flex justify-end gap-2 pt-2">
            <button @click="showSaveViewModal = false" class="px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 rounded-md">Cancelar</button>
            <button @click="saveCurrentView" class="px-4 py-2 text-sm font-medium text-white bg-woot-600 hover:bg-woot-700 rounded-md">Salvar</button>
          </div>
        </div>
      </div>
    </Modal>

    <main class="flex-1 w-full overflow-hidden bg-[#f8fafc]" :class="viewMode === 'list' ? 'overflow-y-auto' : 'overflow-x-auto overflow-y-hidden'">
      <div
        v-if="isLoading && !allConversations.length"
        class="flex h-full items-center justify-center"
      >
        <div class="flex flex-col items-center gap-4">
          <i class="i-lucide-loader-2 animate-spin text-5xl text-woot-600" />
          <p class="text-sm font-semibold text-slate-500">
            {{ t('KANBAN.LOADING') }}
          </p>
        </div>
      </div>

      <!-- Visualização em Lista -->
      <div v-else-if="salesStages.length > 0 && viewMode === 'list'" class="h-full">
        <KanbanListView
          :conversations="filteredConversations"
          :stages="salesStages"
          :current-board="currentBoard"
          :is-loading="isLoading"
          v-model:selected-items="selectedItems"
          @stage-change="handleStageChange"
          @open-item="handleCardClick"
          @contextmenu="handleCardContextmenu"
        />
      </div>

      <!-- Visualização em Calendário -->
      <div v-else-if="salesStages.length > 0 && viewMode === 'calendar'" class="h-full p-4 overflow-hidden">
        <KanbanCalendar
          :items="filteredConversations"
          :stages="salesStages"
          @open-item="handleCardClick"
        />
      </div>

      <!-- Standard Board View -->
      <div
        v-else-if="salesStages.length > 0 && viewMode === 'board' && groupBy === 'none'"
        class="inline-flex h-full items-start gap-4 p-4 md:p-6"
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
            :visible-attributes="visibleAttributes"
            class="shadow-sm border border-slate-200 rounded-xl"
            @stage-change="handleStageChange"
            @card-click="handleCardClick"
            @card-contextmenu="handleCardContextmenu"
          />
        </div>
        <div class="w-4 flex-shrink-0" />
      </div>

      <!-- Swimlane Board View -->
      <div
        v-else-if="salesStages.length > 0 && viewMode === 'board' && groupBy !== 'none'"
        class="flex flex-col h-full bg-[#f8fafc] overflow-y-auto overflow-x-hidden p-4 md:p-6 pb-20 gap-8"
      >
        <div v-for="group in swimlaneGroups" :key="group.id" class="flex flex-col gap-3">
          <!-- Group Header -->
          <div class="sticky left-0 flex items-center gap-2 bg-slate-100/80 backdrop-blur px-3 py-2 rounded-lg border border-slate-200 w-fit">
            <span class="text-sm font-bold text-slate-700">{{ group.name }}</span>
            <span class="text-xs font-semibold bg-white border border-slate-200 px-1.5 py-0.5 rounded-md text-slate-500">
               {{ salesStages.reduce((acc, stage) => acc + getSwimlaneConversations(stage.stage, group.value).length, 0) }}
            </span>
          </div>

          <!-- Group Stages Row -->
           <div class="flex items-start gap-4 overflow-x-auto pb-4">
             <div
               v-for="stage in salesStages"
               :key="stage.stage + group.id"
               class="flex flex-col w-80 flex-shrink-0"
             >
               <!-- We reuse KanbanColumn but it might need style adjustment to not be h-full -->
               <KanbanColumn
                 :stage="stage.stage"
                 :title="stage.title"
                 :color="stage.color"
                 :conversations="getSwimlaneConversations(stage.stage, group.value)"
                 :wip-limit="null" 
                 :visible-attributes="visibleAttributes"
                 class="shadow-sm border border-slate-200 rounded-xl min-h-[150px] max-h-[500px]"
                 @stage-change="(payload) => handleStageChange({...payload, groupUpdate: { type: groupBy, value: group.value }})"
                 @card-click="handleCardClick"
                 @card-contextmenu="handleCardContextmenu"
               />
             </div>
           </div>
        </div>
      </div>

      <div
        v-else
        class="flex h-full flex-col items-center justify-center gap-6 p-8 text-center"
      >
        <div class="rounded-full bg-slate-100 p-6">
          <i class="i-lucide-kanban-square text-6xl text-slate-400" />
        </div>
        <div class="max-w-md space-y-2">
          <h2 class="text-2xl font-bold text-slate-900">
            {{ t('KANBAN.NO_BOARDS_TITLE') }}
          </h2>
          <p class="text-slate-500">
            {{ t('KANBAN.NO_BOARDS_DESCRIPTION') }}
          </p>
        </div>
        <div class="flex items-center gap-3">
          <router-link
            :to="{ name: 'settings_kanban' }"
            class="inline-flex items-center gap-2 rounded-lg bg-woot-600 px-6 py-3 text-sm font-semibold text-white transition-all hover:bg-woot-700 active:scale-95 shadow-md hover:shadow-lg"
          >
            <i class="i-lucide-plus-circle text-lg" />
            {{ t('KANBAN.CREATE_FIRST_BOARD') }}
          </router-link>
          <button
            @click="showHelpModal = true"
            class="inline-flex items-center gap-2 rounded-lg bg-white border border-slate-200 px-6 py-3 text-sm font-semibold text-slate-700 transition-all hover:bg-slate-50 hover:border-slate-300 active:scale-95 shadow-sm hover:shadow-md"
          >
            <i class="i-lucide-book-open text-lg text-woot-600" />
            Ver Exemplos de Uso
          </button>
        </div>
      </div>
    </main>

    <KanbanBulkActions
      v-if="showBulkActions"
      :selected-items="selectedItems"
      :stages="salesStages"
      :current-board="currentBoard"
      @bulk-update="handleBulkUpdate"
      @close="showBulkActions = false"
    />

    <KanbanHelpModal 
      v-if="showHelpModal" 
      :show="showHelpModal" 
      @close="showHelpModal = false" 
    />

    <KanbanItemModal
      v-if="showItemModal && currentBoard"
      :show="showItemModal"
      :board="currentBoard"
      :stage-id="selectedStageId"
      :item="editingItem"
      @close="showItemModal = false"
      @save="handleItemSaved"
    />

    <KanbanContextMenu
      :show="showContextMenu"
      :x="contextMenuX"
      :y="contextMenuY"
      :item="contextMenuItem"
      @close="showContextMenu = false"
      @action="handleContextMenuAction"
    />
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
