<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanColumn from 'dashboard/components/KanbanBoard/KanbanColumn.vue';
import KanbanMetrics from 'dashboard/components/KanbanBoard/KanbanMetrics.vue';
import KanbanListView from './KanbanListView.vue';
import KanbanCalendar from './KanbanCalendar.vue';
import KanbanHelpModal from './KanbanHelpModal.vue';
import KanbanItemModal from './KanbanItemModal.vue';
import KanbanContextMenu from './KanbanContextMenu.vue';
import KanbanBulkActions from './KanbanBulkActions.vue';
import Modal from 'dashboard/components/Modal.vue';
import DropdownContainer from 'next/dropdown-menu/base/DropdownContainer.vue';
import DropdownBody from 'next/dropdown-menu/base/DropdownBody.vue';
import DropdownSection from 'next/dropdown-menu/base/DropdownSection.vue';
import DropdownItem from 'next/dropdown-menu/base/DropdownItem.vue';
import wootConstants from 'dashboard/constants/globals';
import { useAlert } from 'dashboard/composables';

const store = useStore();
const route = useRoute();
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
const boardScroller = ref(null);
const showStageModal = ref(false);
const isSavingStage = ref(false);
const stageFormMode = ref('edit');
const stageForm = ref({
  id: '',
  name: '',
  color: '#3b82f6',
  wipLimit: null,
  insertAfterId: null,
});
const stageColorPresets = [
  '#3b82f6',
  '#0f766e',
  '#d97706',
  '#dc2626',
  '#7c3aed',
  '#1d4ed8',
  '#4f46e5',
  '#059669',
];

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

const stagePreviewStyle = computed(() => ({
  borderTopColor: stageForm.value.color || '#3b82f6',
  background: `linear-gradient(180deg, ${stageForm.value.color || '#3b82f6'}1A 0%, rgba(255, 255, 255, 0) 100%)`,
}));

// Custom attribute key from current board
const customAttributeKey = computed(() => {
  return currentBoard.value?.customAttributeKey || 'sales_stage';
});

// Visible attributes from current board
const visibleAttributes = computed(() => {
  return currentBoard.value?.visible_attributes || [];
});

const hasBoards = computed(() => salesStages.value.length > 0);
const canManageBoards = computed(
  () =>
    store.getters.getCurrentRole === 'administrator' &&
    store.getters.getCurrentCustomRoleId === null
);

// Getters
const allConversations = computed(
  () => store.getters.getAllConversations || []
);

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);

// Agrupar conversas por estágio - OTIMIZADO
const conversationsByStage = computed(() => {
  const grouped = {};
  const attrKey = customAttributeKey.value;
  
  // 1. Initialize buckets for all stages
  salesStages.value.forEach(stage => {
    grouped[stage.stage] = [];
  });

  // 2. Pre-calculate filters to avoid repeated lookups
  const isInboxFiltered = !!selectedInbox.value;
  const currentInboxId = selectedInbox.value;
  
  const isAssigneeFiltered = selectedAssignee.value !== 'all';
  const assigneeMode = selectedAssignee.value; // 'me', 'unassigned', or specific ID
  const currentUserId = store.getters.getCurrentUser.id;

  // 3. Iterate conversations ONCE
  allConversations.value.forEach(conv => {
    // Stage Filter (Basic Distribution)
    const stageId = conv.custom_attributes?.[attrKey];
    if (!stageId || !grouped[stageId]) return;

    // Inbox Filter
    if (isInboxFiltered && conv.inbox_id !== currentInboxId) return;

    // Assignee Filter
    if (isAssigneeFiltered) {
      if (assigneeMode === 'me') {
        if (conv.meta?.assignee?.id !== currentUserId) return;
      } else if (assigneeMode === 'unassigned') {
        if (conv.meta?.assignee) return;
      } else {
        // Specific user ID map if needed, but assuming simple string match logic from original code might need review
        // Original code didn't handle specific ID, only 'me', 'unassigned' or 'all'.
      }
    }

    grouped[stageId].push(conv);
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
      const boardIdFromRoute = route.params.boardId;
      const boardIdFromQuery = router.currentRoute.value.query.board;
      const requestedBoardId = boardIdFromRoute || boardIdFromQuery;

      if (requestedBoardId) {
        const requestedBoard = kanbanConfig.value.boards.find(
          board => board.id.toString() === requestedBoardId.toString()
        );
        selectedBoardId.value = requestedBoard?.id || null;
      }

      if (!selectedBoardId.value) {
        const defaultBoard = kanbanConfig.value.boards.find(b => b.isDefault);
        selectedBoardId.value =
          defaultBoard?.id || kanbanConfig.value.boards[0].id;

        if (route.name === 'kanban_board' && !boardIdFromRoute) {
          router.replace({
            name: 'kanban_board',
            params: {
              ...route.params,
              boardId: selectedBoardId.value,
            },
          });
        }
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

const switchBoard = boardId => {
  if (!boardId) return;

  selectedBoardId.value = boardId;
  router.push({
    name: 'kanban_board',
    params: { boardId },
  });
};

const generateStageId = () => {
  if (window.crypto?.randomUUID) {
    return window.crypto.randomUUID();
  }

  return `stage-${Date.now()}`;
};

const syncBoardRecord = updatedBoard => {
  if (!kanbanConfig.value?.boards) return;

  kanbanConfig.value = {
    ...kanbanConfig.value,
    boards: kanbanConfig.value.boards.map(board =>
      board.id === updatedBoard.id ? updatedBoard : board
    ),
  };
};

const persistBoardStages = async stages => {
  if (!currentBoard.value) return;

  const normalizedStages = stages.map((stage, index) => ({
    ...stage,
    order: index + 1,
  }));

  const updatedBoard = await store.dispatch('kanban/update', {
    ...currentBoard.value,
    stages: normalizedStages,
  });

  syncBoardRecord(updatedBoard);
};

const openStageModal = ({ mode, stageId = null, insertAfterId = null }) => {
  const targetStage = currentBoard.value?.stages?.find(stage => stage.id === stageId);

  stageFormMode.value = mode;
  stageForm.value = {
    id: targetStage?.id || '',
    name: mode === 'duplicate' && targetStage ? `${targetStage.name} (Cópia)` : targetStage?.name || '',
    color: targetStage?.color || '#3b82f6',
    wipLimit: targetStage?.wipLimit ?? null,
    insertAfterId: insertAfterId || stageId,
  };
  showStageModal.value = true;
};

const handleEditStage = stageId => {
  openStageModal({ mode: 'edit', stageId });
};

const handleDuplicateStage = stageId => {
  openStageModal({ mode: 'duplicate', stageId });
};

const handleAddStageAfter = stageId => {
  openStageModal({ mode: 'create', insertAfterId: stageId });
};

const handleAddItemToStage = stageId => {
  openAddItemModal(stageId);
};

const saveStageChanges = async () => {
  if (!currentBoard.value || !stageForm.value.name.trim()) return;

  isSavingStage.value = true;

  try {
    const stages = [...(currentBoard.value.stages || [])];
    const insertIndex = stageForm.value.insertAfterId
      ? stages.findIndex(stage => stage.id === stageForm.value.insertAfterId) + 1
      : stages.length;

    if (stageFormMode.value === 'edit') {
      await persistBoardStages(
        stages.map(stage =>
          stage.id === stageForm.value.id
            ? {
                ...stage,
                name: stageForm.value.name.trim(),
                color: stageForm.value.color,
                wipLimit: stageForm.value.wipLimit === '' ? null : stageForm.value.wipLimit,
              }
            : stage
        )
      );
    } else {
      stages.splice(insertIndex, 0, {
        id: generateStageId(),
        name: stageForm.value.name.trim(),
        color: stageForm.value.color,
        wipLimit: stageForm.value.wipLimit === '' ? null : stageForm.value.wipLimit,
      });

      await persistBoardStages(stages);
    }

    showStageModal.value = false;
    useAlert(t('KANBAN.COLUMN_ACTIONS.SUCCESS'));
  } catch {
    useAlert(t('KANBAN.COLUMN_ACTIONS.ERROR'));
  } finally {
    isSavingStage.value = false;
  }
};

const scrollBoardBy = direction => {
  if (!boardScroller.value) return;

  boardScroller.value.scrollBy({
    left: direction * 320,
    behavior: 'smooth',
  });
};

const scrollToStage = stageId => {
  if (!boardScroller.value) return;

  const stageElement = boardScroller.value.querySelector(`[data-stage-id="${stageId}"]`);
  stageElement?.scrollIntoView({
    behavior: 'smooth',
    inline: 'start',
    block: 'nearest',
  });
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
};

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
  if (!confirm('Tem certeza que deseja excluir este filtro?')) return;

  const currentViews = uiSettings.value.kanban_views || [];
  const updatedViews = currentViews.filter(v => v.id !== viewId);

  try {
    await store.dispatch('updateProfile', {
      ui_settings: {
        ...uiSettings.value,
        kanban_views: updatedViews,
      },
    });
    useAlert('Filtro removido com sucesso');
  } catch (error) {
    useAlert('Erro ao remover filtro');
  }
};

const activeViewButtonClass = mode => {
  return viewMode.value === mode;
};

const boardColumnStyle = computed(() => {
  const stageCount = salesStages.value.length;

  if (stageCount >= 6) {
    return { width: 'clamp(13.5rem, 16vw, 17rem)' };
  }

  if (stageCount >= 5) {
    return { width: 'clamp(14.5rem, 18vw, 18rem)' };
  }

  if (stageCount === 4) {
    return { width: 'clamp(15.5rem, 20vw, 19rem)' };
  }

  return { width: 'clamp(16rem, 24vw, 20rem)' };
});

watch(selectedItems, value => {
  showBulkActions.value = value.length > 0;
});

watch(
  () => route.params.boardId,
  boardId => {
    if (!boardId || !kanbanConfig.value?.boards?.length) return;

    const requestedBoard = kanbanConfig.value.boards.find(
      board => board.id.toString() === boardId.toString()
    );

    if (requestedBoard) {
      selectedBoardId.value = requestedBoard.id;
    }
  }
);

watch([statusFilter, selectedBoardId], () => {
  fetchConversations();
});

onMounted(async () => {
  await loadKanbanConfig();
  await fetchConversations();
});
</script>

<template>
  <div class="flex h-full flex-col bg-n-slate-2">
    <header class="z-20 border-b border-n-weak bg-n-surface-1">
      <div class="flex flex-col gap-4 px-4 py-4 md:px-6">
        <div class="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
          <div class="flex min-w-0 items-start gap-3">
            <div
              class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-n-brand/10 text-n-blue-11"
            >
              <i class="i-lucide-kanban-square text-xl" />
            </div>
            <div class="min-w-0 space-y-3">
              <div class="space-y-1">
                <h1 class="truncate text-xl font-medium text-n-slate-12">
                  {{ currentBoard?.name || t('KANBAN.TITLE') }}
                </h1>
                <p class="text-sm text-n-slate-11">
                  {{ currentBoard?.description || t('KANBAN.WORKSPACE.DEFAULT_DESCRIPTION') }}
                </p>
              </div>

              <div class="flex flex-wrap items-center gap-1 rounded-xl border border-n-weak bg-n-slate-2 p-1">
                <Button
                  sm
                  :blue="activeViewButtonClass('board')"
                  :slate="!activeViewButtonClass('board')"
                  :solid="activeViewButtonClass('board')"
                  :ghost="!activeViewButtonClass('board')"
                  icon="i-lucide-kanban-square"
                  :label="t('KANBAN.VIEW_MODE.BOARD')"
                  @click="viewMode = 'board'"
                />
                <Button
                  sm
                  :blue="activeViewButtonClass('list')"
                  :slate="!activeViewButtonClass('list')"
                  :solid="activeViewButtonClass('list')"
                  :ghost="!activeViewButtonClass('list')"
                  icon="i-lucide-list"
                  :label="t('KANBAN.VIEW_MODE.LIST')"
                  @click="viewMode = 'list'"
                />
                <Button
                  sm
                  :blue="activeViewButtonClass('calendar')"
                  :slate="!activeViewButtonClass('calendar')"
                  :solid="activeViewButtonClass('calendar')"
                  :ghost="!activeViewButtonClass('calendar')"
                  icon="i-lucide-calendar"
                  :label="t('KANBAN.VIEW_MODE.CALENDAR')"
                  @click="viewMode = 'calendar'"
                />
              </div>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <template v-if="hasBoards">
              <router-link
                v-if="canManageBoards && currentBoard"
                :to="{ name: 'kanban_board_edit', params: { boardId: currentBoard.id } }"
              >
                <Button
                  sm
                  slate
                  outline
                  icon="i-lucide-pencil-line"
                  :label="t('KANBAN.FUNNELS.EDIT_FUNNEL')"
                  class="[&>.truncate]:hidden lg:[&>.truncate]:block"
                />
              </router-link>

              <Button
                sm
                slate
                outline
                :icon="showMetrics ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                :label="showMetrics ? t('KANBAN.HIDE_METRICS') : t('KANBAN.SHOW_METRICS')"
                class="[&>.truncate]:hidden lg:[&>.truncate]:block"
                @click="toggleMetrics"
              />

              <Button
                sm
                blue
                solid
                icon="i-lucide-plus"
                :label="t('KANBAN.MODAL.NEW_ITEM')"
                class="[&>.truncate]:hidden md:[&>.truncate]:block"
                @click="openAddItemModal()"
              />

              <Button
                sm
                slate
                faded
                icon="i-lucide-refresh-cw"
                :label="t('KANBAN.REFRESH')"
                :is-loading="isLoading"
                class="[&>.truncate]:hidden lg:[&>.truncate]:block"
                @click="handleRefresh"
              />
            </template>
            <template v-else>
              <router-link :to="{ name: 'kanban_board_new' }">
                <Button
                  sm
                  blue
                  solid
                  icon="i-lucide-plus-circle"
                  :label="t('KANBAN.CREATE_FIRST_BOARD')"
                />
              </router-link>
              <Button
                sm
                slate
                outline
                icon="i-lucide-book-open"
                label="Ver Exemplos de Uso"
                @click="showHelpModal = true"
              />
            </template>
          </div>
        </div>

        <div
          v-if="hasBoards"
          class="flex flex-wrap items-end gap-3"
        >
          <div
            v-if="kanbanConfig && kanbanConfig.boards && kanbanConfig.boards.length > 1"
            class="w-full space-y-1 md:w-[260px]"
          >
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.BOARD') }}
            </label>
            <DropdownContainer>
              <template #trigger="{ toggle }">
                <button
                  class="flex h-10 w-full items-center justify-between rounded-xl border border-n-weak bg-n-surface-1 px-3 text-left text-sm text-n-slate-12 transition hover:border-n-brand/30"
                  @click="toggle"
                >
                  <span class="truncate font-medium">{{ currentBoard?.name || t('KANBAN.NAV.FUNNELS') }}</span>
                  <div class="flex items-center gap-2">
                    <span class="rounded-full bg-n-slate-2 px-2 py-0.5 text-[10px] font-semibold text-n-slate-11">
                      {{ kanbanConfig.boards.length }}
                    </span>
                    <i class="i-lucide-chevron-down text-sm text-n-slate-10" />
                  </div>
                </button>
              </template>

              <DropdownBody class="left-0 top-full z-50 mt-2 min-w-[24rem]" strong>
                <DropdownSection>
                  <div class="flex items-start justify-between gap-4 px-4 py-3">
                    <div>
                      <p class="text-lg font-medium text-n-slate-12">{{ t('KANBAN.NAV.FUNNELS') }}</p>
                      <p class="mt-1 text-sm text-n-slate-11">{{ t('KANBAN.FUNNEL_SWITCHER.DESCRIPTION') }}</p>
                    </div>
                    <router-link v-if="canManageBoards" :to="{ name: 'kanban_board_new' }">
                      <Button sm slate faded icon="i-lucide-plus" :label="t('KANBAN.NAV.NEW_FUNNEL')" />
                    </router-link>
                  </div>
                </DropdownSection>

                <DropdownSection>
                  <button
                    v-for="board in kanbanConfig.boards"
                    :key="board.id"
                    class="flex w-full items-center justify-between gap-3 px-4 py-3 text-left transition-colors hover:bg-n-slate-2"
                    @click="switchBoard(board.id)"
                  >
                    <div class="min-w-0 flex items-center gap-3">
                      <i class="i-lucide-star text-sm text-n-slate-10" />
                      <div class="min-w-0">
                        <p class="truncate text-sm font-medium text-n-slate-12">{{ board.name }}</p>
                        <p v-if="board.description" class="truncate text-xs text-n-slate-10">{{ board.description }}</p>
                      </div>
                    </div>
                    <i v-if="currentBoard?.id === board.id" class="i-lucide-check text-n-teal-10" />
                  </button>
                </DropdownSection>
              </DropdownBody>
            </DropdownContainer>
          </div>

          <div class="w-full space-y-1 md:w-[180px]">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.FILTERS.GROUP_BY') }}
            </label>
            <select
              v-model="groupBy"
              class="h-10 w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            >
              <option value="none">{{ t('KANBAN.FILTERS.GROUP_BY_OPTIONS.NONE') }}</option>
              <option value="priority">{{ t('KANBAN.FILTERS.GROUP_BY_OPTIONS.PRIORITY') }}</option>
              <option value="assignee">{{ t('KANBAN.FILTERS.GROUP_BY_OPTIONS.ASSIGNEE') }}</option>
            </select>
          </div>

          <div class="w-full space-y-1 md:w-[220px]">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.FILTERS.INBOX') }}
            </label>
            <select
              v-model="selectedInbox"
              class="h-10 w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            >
              <option :value="null">{{ t('KANBAN.FILTERS.ALL_INBOXES') }}</option>
              <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
                {{ inbox.name }}
              </option>
            </select>
          </div>

          <div class="w-full space-y-1 md:w-[220px]">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.FILTERS.ASSIGNEE') }}
            </label>
            <select
              v-model="selectedAssignee"
              class="h-10 w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            >
              <option value="all">{{ t('KANBAN.FILTERS.ALL_AGENTS') }}</option>
              <option value="me">{{ t('KANBAN.FILTERS.MY_DEALS') }}</option>
              <option value="unassigned">{{ t('KANBAN.FILTERS.UNASSIGNED') }}</option>
            </select>
          </div>

          <div class="w-full space-y-1 md:w-[160px]">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.FILTERS.STATUS') }}
            </label>
            <select
              v-model="statusFilter"
              class="h-10 w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            >
              <option value="open">{{ t('KANBAN.FILTERS.STATUS_OPTIONS.OPEN') }}</option>
              <option value="resolved">{{ t('KANBAN.FILTERS.STATUS_OPTIONS.RESOLVED') }}</option>
              <option value="all">{{ t('KANBAN.FILTERS.STATUS_OPTIONS.ALL') }}</option>
            </select>
          </div>

          <div class="flex w-full items-end justify-start md:ml-auto md:w-auto md:justify-end">
            <DropdownContainer>
              <template #trigger="{ toggle }">
                <Button
                  sm
                  slate
                  outline
                  icon="i-lucide-bookmark"
                  :label="t('KANBAN.FILTERS.SAVED_VIEWS')"
                  class="[&>.truncate]:hidden md:[&>.truncate]:block"
                  @click="toggle"
                />
              </template>
              <DropdownBody class="right-0 top-full z-50 mt-2 min-w-72" strong>
                <DropdownSection v-if="savedViews.length">
                  <div
                    v-for="view in savedViews"
                    :key="view.id"
                    class="flex items-center gap-2 px-2 py-1"
                  >
                    <button
                      class="flex min-w-0 flex-1 items-center gap-2 rounded-lg px-2 py-2 text-left text-sm text-n-slate-12 hover:bg-n-slate-2"
                      @click="applyView(view)"
                    >
                      <i class="i-lucide-bookmark text-n-blue-11" />
                      <span class="truncate">{{ view.name }}</span>
                    </button>
                    <button
                      class="rounded-lg p-2 text-n-ruby-11 hover:bg-n-ruby-3"
                      @click="deleteView(view.id)"
                    >
                      <i class="i-lucide-trash-2" />
                    </button>
                  </div>
                </DropdownSection>
                <DropdownSection v-else>
                  <div class="px-3 py-2 text-sm text-n-slate-11">
                    {{ t('KANBAN.FILTERS.NO_SAVED_VIEWS') }}
                  </div>
                </DropdownSection>
                <DropdownSection>
                  <DropdownItem
                    icon="i-lucide-plus"
                    :label="t('KANBAN.FILTERS.SAVE_CURRENT_VIEW')"
                    :click="() => (showSaveViewModal = true)"
                  />
                </DropdownSection>
              </DropdownBody>
            </DropdownContainer>
          </div>
        </div>

        <div
          v-if="hasBoards && viewMode === 'board'"
          class="flex flex-col gap-2 border-t border-n-weak pt-3 md:flex-row md:items-center md:justify-between"
        >
          <div class="min-w-0">
            <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.NAVIGATION.TITLE') }}
            </p>
            <div class="custom-scrollbar mt-2 flex gap-2 overflow-x-auto pb-1">
              <button
                v-for="stage in salesStages"
                :key="`nav-${stage.stage}`"
                class="inline-flex flex-shrink-0 items-center gap-2 rounded-xl px-3 py-2 text-sm font-medium text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-slate-12"
                @click="scrollToStage(stage.stage)"
              >
                <span class="h-2.5 w-2.5 rounded-full" :style="{ backgroundColor: stage.color }" />
                <span class="truncate">{{ stage.title }}</span>
                <span class="rounded-full bg-n-slate-2 px-2 py-0.5 text-xs text-n-slate-11">
                  {{ conversationsByStage[stage.stage]?.length || 0 }}
                </span>
              </button>
            </div>
          </div>

          <div class="flex items-center gap-2 self-end md:self-auto">
            <Button
              sm
              slate
              outline
              icon="i-lucide-chevron-left"
              :label="t('KANBAN.NAVIGATION.PREVIOUS')"
              class="[&>.truncate]:hidden lg:[&>.truncate]:block"
              @click="scrollBoardBy(-1)"
            />
            <Button
              sm
              slate
              outline
              icon="i-lucide-chevron-right"
              :label="t('KANBAN.NAVIGATION.NEXT')"
              class="[&>.truncate]:hidden lg:[&>.truncate]:block"
              @click="scrollBoardBy(1)"
            />
          </div>
        </div>
      </div>
    </header>

    <transition name="fade">
      <div v-if="showMetrics && filteredConversations.length" class="border-b border-n-weak bg-n-surface-1 px-4 py-4 md:px-6">
        <KanbanMetrics :conversations="filteredConversations" />
      </div>
    </transition>

    <Modal :show="showSaveViewModal" :on-close="() => (showSaveViewModal = false)">
      <div class="w-full max-w-md p-6">
        <h3 class="mb-4 text-lg font-medium text-n-slate-12">Salvar Vista Atual</h3>
        <div class="space-y-4">
          <div>
            <label class="mb-1 block text-sm font-medium text-n-slate-12">Nome da Vista</label>
            <input
              v-model="newViewName"
              type="text"
              class="w-full rounded-xl border border-n-weak px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              placeholder="Ex: Tickets Alta Prioridade"
            >
          </div>
          <div class="rounded-xl bg-n-slate-2 p-3 text-sm text-n-slate-11">
            <p class="mb-1 font-medium text-n-slate-12">Filtros que serão salvos:</p>
            <ul class="list-inside list-disc space-y-1 text-xs">
              <li>Inbox: {{ selectedInbox ? inboxes.find(i => i.id === selectedInbox)?.name : 'Todos' }}</li>
              <li>Agente: {{ selectedAssignee === 'me' ? 'Eu' : (selectedAssignee === 'all' ? 'Todos' : selectedAssignee) }}</li>
              <li>Status: {{ statusFilter }}</li>
            </ul>
          </div>
          <div class="flex justify-end gap-2 pt-2">
            <Button slate outline sm label="Cancelar" @click="showSaveViewModal = false" />
            <Button blue solid sm label="Salvar" @click="saveCurrentView" />
          </div>
        </div>
      </div>
    </Modal>

    <Modal :show="showStageModal" :on-close="() => (showStageModal = false)">
      <div class="w-full max-w-lg p-6">
        <h3 class="text-lg font-medium text-n-slate-12">
          {{ t(`KANBAN.COLUMN_ACTIONS.MODAL.${stageFormMode.toUpperCase()}_TITLE`) }}
        </h3>
        <div class="mt-5 space-y-4">
          <div class="space-y-1.5">
            <label class="block text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.COLUMN_ACTIONS.STAGE_NAME') }}
            </label>
            <input
              v-model="stageForm.name"
              type="text"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
              :placeholder="t('KANBAN.COLUMN_ACTIONS.STAGE_NAME_PLACEHOLDER')"
            />
          </div>

          <div class="grid gap-4 sm:grid-cols-2">
            <div class="space-y-1.5">
              <label class="block text-xs font-medium uppercase tracking-wide text-n-slate-10">
                {{ t('KANBAN.COLUMN_ACTIONS.COLOR') }}
              </label>
              <input
                v-model="stageForm.color"
                type="color"
                class="h-11 w-full rounded-xl border border-n-weak bg-n-surface-1 px-2 py-2"
              />
              <div class="flex flex-wrap gap-2 pt-1">
                <button
                  v-for="color in stageColorPresets"
                  :key="color"
                  type="button"
                  class="h-7 w-7 rounded-full border-2 transition-transform hover:scale-105"
                  :class="stageForm.color === color ? 'border-n-slate-12' : 'border-white/70'"
                  :style="{ backgroundColor: color }"
                  :title="color"
                  @click="stageForm.color = color"
                />
              </div>
            </div>

            <div class="space-y-1.5">
              <label class="block text-xs font-medium uppercase tracking-wide text-n-slate-10">
                {{ t('KANBAN.COLUMN_ACTIONS.WIP_LIMIT') }}
              </label>
              <input
                v-model.number="stageForm.wipLimit"
                type="number"
                min="0"
                class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
                :placeholder="t('KANBAN.COLUMN_ACTIONS.WIP_LIMIT_PLACEHOLDER')"
              />
            </div>
          </div>

          <div
            class="rounded-2xl border border-n-weak px-4 py-3"
            :style="stagePreviewStyle"
          >
            <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.COLUMN_ACTIONS.PREVIEW') }}
            </p>
            <div class="mt-2 flex items-center justify-between gap-3">
              <div class="min-w-0">
                <p class="truncate text-sm font-medium text-n-slate-12">
                  {{ stageForm.name || t('KANBAN.COLUMN_ACTIONS.STAGE_NAME_PLACEHOLDER') }}
                </p>
                <p class="mt-1 text-xs text-n-slate-10">
                  {{ stageForm.wipLimit ? `${t('KANBAN.COLUMN_ACTIONS.WIP_LIMIT')}: ${stageForm.wipLimit}` : t('KANBAN.COLUMN_ACTIONS.WIP_LIMIT_PLACEHOLDER') }}
                </p>
              </div>
              <span
                class="rounded-full border px-2 py-1 text-xs font-medium"
                :style="{
                  borderColor: `${stageForm.color}33`,
                  color: stageForm.color,
                  backgroundColor: `${stageForm.color}1A`,
                }"
              >
                {{ t('KANBAN.COLUMN_ACTIONS.PREVIEW') }}
              </span>
            </div>
          </div>

          <div class="flex justify-end gap-2 pt-2">
            <Button slate outline sm :label="t('KANBAN.MODAL.CANCEL')" @click="showStageModal = false" />
            <Button blue solid sm :is-loading="isSavingStage" :label="t('KANBAN.COLUMN_ACTIONS.SAVE_STAGE')" @click="saveStageChanges" />
          </div>
        </div>
      </div>
    </Modal>

    <main
      ref="boardScroller"
      class="custom-scrollbar flex min-h-0 flex-1 w-full bg-n-slate-2"
      :class="viewMode === 'board' ? 'overflow-auto' : 'overflow-y-auto overflow-x-hidden'"
    >
        <div
          v-if="isLoading && !allConversations.length"
          class="flex h-full items-center justify-center"
        >
          <div class="flex flex-col items-center gap-4">
            <i class="i-lucide-loader-2 animate-spin text-5xl text-n-brand" />
            <p class="text-sm font-medium text-n-slate-11">
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
        <div v-else-if="salesStages.length > 0 && viewMode === 'calendar'" class="h-full overflow-hidden p-4 md:p-6">
          <KanbanCalendar
            :items="filteredConversations"
            :stages="salesStages"
            @open-item="handleCardClick"
          />
        </div>

        <!-- Standard Board View -->
        <div
          v-else-if="salesStages.length > 0 && viewMode === 'board' && groupBy === 'none'"
          class="flex min-h-full min-w-max snap-x snap-mandatory items-start gap-3 p-3 pb-5 md:gap-4 md:p-5 md:pb-6"
        >
          <div
            v-for="stage in salesStages"
            :key="stage.stage"
            :data-stage-id="stage.stage"
            :style="boardColumnStyle"
            class="flex min-h-[calc(100vh-20rem)] min-w-[13.5rem] flex-shrink-0 snap-start flex-col"
          >
            <KanbanColumn
              :stage="stage.stage"
              :title="stage.title"
              :color="stage.color"
              :conversations="conversationsByStage[stage.stage] || []"
              :wip-limit="stage.wipLimit"
              :visible-attributes="visibleAttributes"
              :can-manage-board="canManageBoards"
              @stage-change="handleStageChange"
              @card-click="handleCardClick"
              @card-contextmenu="handleCardContextmenu"
              @edit-stage="handleEditStage"
              @duplicate-stage="handleDuplicateStage"
              @add-stage-after="handleAddStageAfter"
              @add-item="handleAddItemToStage"
            />
          </div>
          <div class="w-4 flex-shrink-0" />
        </div>

        <!-- Swimlane Board View -->
        <div
          v-else-if="salesStages.length > 0 && viewMode === 'board' && groupBy !== 'none'"
          class="flex min-h-full min-w-max flex-col gap-6 p-3 pb-16 md:gap-8 md:p-5 md:pb-20"
        >
          <div v-for="group in swimlaneGroups" :key="group.id" class="flex flex-col gap-3">
            <div class="sticky left-0 flex w-fit items-center gap-2 rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2">
              <span class="text-sm font-medium text-n-slate-12">{{ group.name }}</span>
              <span class="rounded-lg bg-n-slate-2 px-1.5 py-0.5 text-xs font-medium text-n-slate-11">
                 {{ salesStages.reduce((acc, stage) => acc + getSwimlaneConversations(stage.stage, group.value).length, 0) }}
              </span>
            </div>

  	         <div class="custom-scrollbar flex min-w-max snap-x snap-mandatory items-start gap-3 overflow-x-auto pb-4 md:gap-4">
               <div
                 v-for="stage in salesStages"
                 :key="stage.stage + group.id"
                 :data-stage-id="`${group.id}-${stage.stage}`"
                   :style="boardColumnStyle"
                   class="flex min-w-[13.5rem] flex-shrink-0 snap-start flex-col"
               >
                 <KanbanColumn
                   :stage="stage.stage"
                   :title="stage.title"
                   :color="stage.color"
                   :conversations="getSwimlaneConversations(stage.stage, group.value)"
                   :wip-limit="null" 
                   :visible-attributes="visibleAttributes"
                   :can-manage-board="canManageBoards"
                   class="min-h-[150px] max-h-[calc(100vh-24rem)]"
                   @stage-change="(payload) => handleStageChange({...payload, groupUpdate: { type: groupBy, value: group.value }})"
                   @card-click="handleCardClick"
                   @card-contextmenu="handleCardContextmenu"
                   @edit-stage="handleEditStage"
                   @duplicate-stage="handleDuplicateStage"
                   @add-stage-after="handleAddStageAfter"
                   @add-item="handleAddItemToStage"
                 />
               </div>
             </div>
          </div>
        </div>

        <div v-else class="flex h-full items-center justify-center p-6 md:p-8">
          <div class="flex w-full max-w-3xl flex-col items-center rounded-[28px] border border-n-weak bg-n-surface-1 px-6 py-12 text-center shadow-sm md:px-12 md:py-16">
            <div class="mb-5 flex h-20 w-20 items-center justify-center rounded-3xl bg-n-brand/10 text-n-blue-11">
              <i class="i-lucide-kanban-square text-4xl" />
            </div>
            <h2 class="text-3xl font-medium text-n-slate-12">
              {{ t('KANBAN.NO_BOARDS_TITLE') }}
            </h2>
            <p class="mt-3 max-w-2xl text-base text-n-slate-11">
              {{ t('KANBAN.NO_BOARDS_DESCRIPTION') }}
            </p>
            <div class="mt-8 flex flex-col items-center gap-3 sm:flex-row">
              <router-link :to="{ name: 'kanban_board_new' }">
                <Button blue solid icon="i-lucide-plus-circle" :label="t('KANBAN.CREATE_FIRST_BOARD')" />
              </router-link>
              <Button slate outline icon="i-lucide-book-open" label="Ver Exemplos de Uso" @click="showHelpModal = true" />
            </div>
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