<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import KanbanBoardEditor from './KanbanBoardEditor.vue';

const store = useStore();
const { t } = useI18n();

const kanbanConfig = ref(null);
const isLoading = ref(true);
const selectedBoard = ref(null);
const showEditor = ref(false);

const accountId = computed(() => store.getters.getCurrentAccountId);

const loadConfig = async () => {
  isLoading.value = true;
  try {
    const response = await window.axios.get(
      `/api/v1/accounts/${accountId.value}/kanban_settings`
    );
    kanbanConfig.value = response.data;
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const createBoard = () => {
  selectedBoard.value = {
    name: t('KANBAN_SETTINGS.NEW_BOARD'),
    description: '',
    stages: [
      {
        id: `stage-${Date.now()}`,
        name: t('KANBAN_SETTINGS.NEW_STAGE'),
        color: '#3b82f6',
        order: 1,
        wipLimit: null,
      },
    ],
    customAttributeKey: 'sales_stage',
    valueAttributeKey: 'deal_value',
    isDefault: false,
  };
  showEditor.value = true;
};

const editBoard = board => {
  selectedBoard.value = { ...board };
  showEditor.value = true;
};

const saveBoard = async boardData => {
  try {
    if (boardData.id) {
      // Update existing
      await window.axios.put(
        `/api/v1/accounts/${accountId.value}/kanban_settings/boards/${boardData.id}`,
        { board: boardData }
      );
      useAlert(t('KANBAN_SETTINGS.BOARD_UPDATED'));
    } else {
      // Create new
      await window.axios.post(
        `/api/v1/accounts/${accountId.value}/kanban_settings/boards`,
        { board: boardData }
      );
      useAlert(t('KANBAN_SETTINGS.BOARD_CREATED'));
    }

    await loadConfig();
    showEditor.value = false;
    selectedBoard.value = null;
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.SAVE_ERROR'));
  }
};

const deleteBoard = async boardId => {
  if (!confirm(t('KANBAN_SETTINGS.CONFIRM_DELETE'))) return;

  try {
    await axios.delete(
      `/api/v1/accounts/${accountId.value}/kanban_settings/boards/${boardId}`
    );
    useAlert(t('KANBAN_SETTINGS.DELETE_SUCCESS'));
    await loadConfig();
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.DELETE_ERROR'));
  }
};

const closeEditor = () => {
  showEditor.value = false;
  selectedBoard.value = null;
};

onMounted(() => {
  loadConfig();
});
</script>

<template>
  <SettingsLayout
    :title="$t('KANBAN_SETTINGS.TITLE')"
    :sub-title="$t('KANBAN_SETTINGS.DESCRIPTION')"
    icon-name="i-lucide-kanban-square"
  >
    <div v-if="isLoading" class="flex items-center justify-center p-12">
      <i class="i-lucide-loader-2 animate-spin text-4xl text-n-brand" />
    </div>

    <div v-else class="flex flex-col gap-6 p-6">
      <!-- Header com botão de criar -->
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-xl font-semibold text-n-slate-12">
            {{ $t('KANBAN_SETTINGS.BOARDS_TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ $t('KANBAN_SETTINGS.BOARDS_DESCRIPTION') }}
          </p>
        </div>
        <button
          class="inline-flex items-center gap-2 px-4 py-2 bg-n-brand text-white rounded-lg hover:bg-n-brand/90 transition-colors"
          @click="createBoard"
        >
          <i class="i-lucide-plus" />
          {{ $t('KANBAN_SETTINGS.CREATE_BOARD') }}
        </button>
      </div>

      <!-- Lista de boards -->
      <div
        v-if="kanbanConfig?.boards?.length > 0"
        class="grid gap-4 md:grid-cols-2 lg:grid-cols-3"
      >
        <div
          v-for="board in kanbanConfig.boards"
          :key="board.id"
          class="group relative flex flex-col gap-3 p-4 border border-n-weak rounded-lg bg-white hover:border-n-brand hover:shadow-md transition-all"
        >
          <!-- Badge de default -->
          <div
            v-if="board.isDefault"
            class="absolute top-3 right-3 px-2 py-0.5 bg-n-brand/10 text-n-brand text-xs font-medium rounded"
          >
            {{ $t('KANBAN_SETTINGS.DEFAULT') }}
          </div>

          <!-- Info do board -->
          <div class="flex items-start gap-3">
            <div
              class="flex-shrink-0 w-10 h-10 rounded-lg bg-n-brand/10 flex items-center justify-center"
            >
              <i class="i-lucide-kanban-square text-lg text-n-brand" />
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-n-slate-12 truncate">
                {{ board.name }}
              </h3>
              <p
                v-if="board.description"
                class="text-sm text-n-slate-11 line-clamp-2 mt-1"
              >
                {{ board.description }}
              </p>
            </div>
          </div>

          <!-- Estágios -->
          <div class="flex flex-wrap gap-1.5">
            <div
              v-for="stage in board.stages?.slice(0, 5)"
              :key="stage.id"
              class="inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium text-white"
              :style="{ backgroundColor: stage.color }"
            >
              {{ stage.name }}
            </div>
            <div
              v-if="board.stages?.length > 5"
              class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-n-slate-3 text-n-slate-11"
            >
              +{{ board.stages.length - 5 }}
            </div>
          </div>

          <!-- Ações -->
          <div class="flex items-center gap-2 pt-2 border-t border-n-weak">
            <button
              class="flex-1 px-3 py-1.5 text-sm font-medium text-n-slate-12 hover:bg-n-slate-2 rounded transition-colors"
              @click="editBoard(board)"
            >
              <i class="i-lucide-edit-2 mr-1" />
              {{ $t('KANBAN_SETTINGS.EDIT') }}
            </button>
            <button
              class="px-3 py-1.5 text-sm font-medium text-red-600 hover:bg-red-50 rounded transition-colors"
              @click="deleteBoard(board.id)"
            >
              <i class="i-lucide-trash-2" />
            </button>
          </div>
        </div>
      </div>

      <!-- Empty state -->
      <div
        v-else
        class="flex flex-col items-center justify-center p-12 border-2 border-dashed border-n-weak rounded-lg bg-n-slate-1"
      >
        <i class="i-lucide-kanban-square text-6xl text-n-slate-6 mb-4" />
        <h3 class="text-lg font-semibold text-n-slate-12 mb-2">
          {{ $t('KANBAN_SETTINGS.NO_BOARDS') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t('KANBAN_SETTINGS.NO_BOARDS_DESCRIPTION') }}
        </p>
        <button
          class="inline-flex items-center gap-2 px-4 py-2 bg-n-brand text-white rounded-lg hover:bg-n-brand/90 transition-colors"
          @click="createBoard"
        >
          <i class="i-lucide-plus" />
          {{ $t('KANBAN_SETTINGS.CREATE_FIRST_BOARD') }}
        </button>
      </div>
    </div>

    <!-- Editor Modal -->
    <KanbanBoardEditor
      v-if="showEditor"
      :board="selectedBoard"
      @save="saveBoard"
      @close="closeEditor"
    />
  </SettingsLayout>
</template>
