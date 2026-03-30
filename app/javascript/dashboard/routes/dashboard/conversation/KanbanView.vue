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
const showMetrics = ref(false);
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

const activeViewButtonClass = mode => {
  return viewMode.value === mode;
};

const boardColumnMinWidth = computed(() => {
  return '20rem';
});

const boardLayoutClass = computed(() => {
  return 'inline-flex min-h-0 gap-3 p-3 pb-4 md:gap-4 md:p-4';
});

const boardLayoutStyle = computed(() => {
  if (!salesStages.value.length) {
    return {};
  }

  return {
    width: 'max-content',
  };
});

const boardColumnClass = computed(() => {
  return 'flex h-full min-h-0 min-w-[20rem] w-[20rem] flex-col';
});

const swimlaneTrackClass = computed(() => {
  return 'inline-flex min-h-0 gap-3 md:gap-4';
});

const swimlaneTrackStyle = computed(() => {
  if (!salesStages.value.length) {
    return {};
  }

  return {
    width: 'max-content',
  };
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
  <div class="flex h-full min-h-0 min-w-0 flex-col bg-n-slate-2 p-3 md:p-4">
    <section class="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden rounded-2xl border border-n-weak bg-n-surface-1">
      <header class="shrink-0 border-b border-n-weak px-4 py-3 md:px-6">
        <div class="flex flex-col gap-3">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div class="flex min-w-0 flex-wrap items-center gap-2 md:gap-3">
              <div v-if="hasBoards" class="min-w-0">
                <select
                  v-if="!route.params.boardId && kanbanConfig && kanbanConfig.boards && kanbanConfig.boards.length > 1"
                  v-model="selectedBoardId"
                  class="h-10 min-w-[220px] max-w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm font-medium text-n-slate-12 outline-none transition focus:border-n-brand"
                >
                  <option
                    v-for="board in kanbanConfig.boards"
                    :key="board.id"
                    :value="board.id"
                  >
                    {{ board.name }}
                  </option>
                </select>
                <div v-else class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
                  <i class="i-lucide-chevron-down text-xs text-n-slate-9" />
                  <span class="truncate">{{ currentBoard?.name || t('KANBAN.TITLE') }}</span>
                  <span class="rounded-full bg-n-slate-2 px-2 py-0.5 text-xs text-n-slate-11">
                    {{ filteredConversations.length }}
                  </span>
                </div>
              </div>

              <div class="inline-flex items-center gap-1 rounded-xl border border-n-weak bg-n-slate-2 p-1">
                <Button
                  sm
                  :blue="activeViewButtonClass('board')"
                  :slate="!activeViewButtonClass('board')"
                  :solid="activeViewButtonClass('board')"
                  :ghost="!activeViewButtonClass('board')"
                  icon="i-lucide-kanban-square"
                  label="Quadro"
                  @click="viewMode = 'board'"
                />
                <Button
                  sm
                  :blue="activeViewButtonClass('list')"
                  :slate="!activeViewButtonClass('list')"
                  :solid="activeViewButtonClass('list')"
                  :ghost="!activeViewButtonClass('list')"
                  icon="i-lucide-list"
                  label="Lista"
                  @click="viewMode = 'list'"
                />
                <Button
                  sm
                  :blue="activeViewButtonClass('calendar')"
                  :slate="!activeViewButtonClass('calendar')"
                  :solid="activeViewButtonClass('calendar')"
                  :ghost="!activeViewButtonClass('calendar')"
                  icon="i-lucide-calendar"
                  label="Calendário"
                  @click="viewMode = 'calendar'"
                />
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
                  />
                </router-link>

                <Button
                  sm
                  slate
                  outline
                  :icon="showMetrics ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                  :label="showMetrics ? t('KANBAN.HIDE_METRICS') : t('KANBAN.SHOW_METRICS')"
                  @click="toggleMetrics"
                />

                <Button
                  sm
                  blue
                  solid
                  icon="i-lucide-plus"
                  :label="t('KANBAN.MODAL.NEW_ITEM')"
                  @click="openAddItemModal()"
                />

                <Button
                  sm
                  slate
                  faded
                  icon="i-lucide-refresh-cw"
                  :label="t('KANBAN.REFRESH')"
                  :is-loading="isLoading"
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
        </div>
      </header>

      <transition name="fade">
        <div v-if="showMetrics && filteredConversations.length" class="shrink-0 border-b border-n-weak px-4 py-3 md:px-6">
        <KanbanMetrics
          :conversations="filteredConversations"
          :stages="salesStages"
          :stage-attribute-key="customAttributeKey"
        />
        </div>
      </transition>

    <main class="flex min-h-0 flex-1 w-full min-w-0 items-stretch overflow-hidden bg-n-slate-2">
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
      <div v-else-if="salesStages.length > 0 && viewMode === 'list'" class="flex h-full min-h-0 w-full min-w-0 flex-1 basis-full overflow-hidden">
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
      <div v-else-if="salesStages.length > 0 && viewMode === 'calendar'" class="flex h-full min-h-0 w-full min-w-0 flex-1 basis-full overflow-hidden">
        <KanbanCalendar
          :items="filteredConversations"
          :stages="salesStages"
          @open-item="handleCardClick"
        />
      </div>

      <!-- Standard Board View -->
      <div
        v-else-if="salesStages.length > 0 && viewMode === 'board' && groupBy === 'none'"
        class="kanban-board-scroll custom-scrollbar h-full min-h-0 w-full min-w-0 flex-1 overflow-x-auto overflow-y-hidden bg-n-slate-2 px-3 pb-3 pt-2 md:px-4 md:pb-4"
      >
        <div class="h-full min-h-0 items-start" :class="boardLayoutClass" :style="boardLayoutStyle">
          <div
            v-for="stage in salesStages"
            :key="stage.stage"
            :class="boardColumnClass"
          >
            <KanbanColumn
              :stage="stage.stage"
              :title="stage.title"
              :color="stage.color"
              :conversations="conversationsByStage[stage.stage] || []"
              :wip-limit="stage.wipLimit"
              :visible-attributes="visibleAttributes"
              @add-item="openAddItemModal"
              @stage-change="handleStageChange"
              @card-click="handleCardClick"
              @card-contextmenu="handleCardContextmenu"
            />
          </div>
        </div>
      </div>

      <!-- Swimlane Board View -->
      <div
        v-else-if="salesStages.length > 0 && viewMode === 'board' && groupBy !== 'none'"
        class="kanban-board-scroll custom-scrollbar flex h-full min-h-0 w-full min-w-0 flex-1 flex-col gap-6 overflow-x-auto overflow-y-auto bg-n-slate-2 p-3 pb-4 pt-2 md:p-4"
      >
        <div v-for="group in swimlaneGroups" :key="group.id" class="flex flex-col gap-3">
          <div class="sticky left-0 flex w-fit items-center gap-2 rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2">
            <span class="text-sm font-medium text-n-slate-12">{{ group.name }}</span>
            <span class="rounded-lg bg-n-slate-2 px-1.5 py-0.5 text-xs font-medium text-n-slate-11">
               {{ salesStages.reduce((acc, stage) => acc + getSwimlaneConversations(stage.stage, group.value).length, 0) }}
            </span>
          </div>

           <div :class="swimlaneTrackClass" :style="swimlaneTrackStyle">
             <div
               v-for="stage in salesStages"
               :key="stage.stage + group.id"
               :class="boardColumnClass"
             >
               <KanbanColumn
                 :stage="stage.stage"
                 :title="stage.title"
                 :color="stage.color"
                 :conversations="getSwimlaneConversations(stage.stage, group.value)"
                 :wip-limit="null" 
                 :visible-attributes="visibleAttributes"
                 class="h-full min-h-[150px]"
                 @add-item="openAddItemModal"
                 @stage-change="(payload) => handleStageChange({...payload, groupUpdate: { type: groupBy, value: group.value }})"
                 @card-click="handleCardClick"
                 @card-contextmenu="handleCardContextmenu"
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
    </section>

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

.kanban-board-scroll {
  scrollbar-gutter: stable both-edges;
}

.kanban-board-scroll::-webkit-scrollbar {
  height: 12px;
}

.kanban-board-scroll::-webkit-scrollbar-track {
  background: #e2e8f0;
  border-radius: 9999px;
}

.kanban-board-scroll::-webkit-scrollbar-thumb {
  background: #94a3b8;
  border-radius: 9999px;
  border: 2px solid #e2e8f0;
}

.kanban-board-scroll::-webkit-scrollbar-thumb:hover {
  background: #64748b;
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

</style>