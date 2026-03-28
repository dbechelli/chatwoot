<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import EmptyStateLayout from 'dashboard/components-next/EmptyStateLayout.vue';
import SettingsLayout from '../SettingsLayout.vue';
import KanbanBoardEditor from './KanbanBoardEditor.vue';
import KanbanTemplates from './KanbanTemplates.vue';

const store = useStore();
const { t } = useI18n();

const kanbanConfig = ref(null);
const isLoading = ref(true);
const selectedBoard = ref(null);
const showEditor = ref(false);
const showTemplates = ref(false);

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
  showTemplates.value = true;
};

const createFromTemplate = templateData => {
  selectedBoard.value = templateData;
  showEditor.value = true;
  showTemplates.value = false;
};

const createBlankBoard = () => {
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
  // eslint-disable-next-line no-alert, no-restricted-globals
  if (!confirm(t('KANBAN_SETTINGS.CONFIRM_DELETE'))) return;

  try {
    await window.axios.delete(
      `/api/v1/accounts/${accountId.value}/kanban_settings/boards/${boardId}`
    );
    useAlert(t('KANBAN_SETTINGS.DELETE_SUCCESS'));
    await loadConfig();
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.DELETE_ERROR'));
  }
};

const duplicateBoard = async board => {
  try {
    await window.axios.post(
      `/api/v1/accounts/${accountId.value}/kanban_settings/boards/${board.id}/duplicate`
    );
    useAlert(t('KANBAN_SETTINGS.DUPLICATE_SUCCESS'));
    await loadConfig();
  } catch (error) {
    useAlert(t('KANBAN_SETTINGS.DUPLICATE_ERROR'));
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
    <div
      v-if="isLoading"
      class="flex items-center justify-center rounded-2xl border border-n-weak bg-n-surface-1 p-12"
    >
      <i class="i-lucide-loader-2 animate-spin text-4xl text-n-brand" />
    </div>

    <div v-else class="flex flex-col gap-4 md:gap-6 p-4 md:p-6">
      <div
        class="flex flex-col gap-4 rounded-2xl border border-n-weak bg-n-surface-1 p-4 md:flex-row md:items-center md:justify-between md:p-5"
      >
        <div>
          <h2 class="text-base font-semibold text-n-slate-12 md:text-lg">
            {{ $t('KANBAN_SETTINGS.BOARDS_TITLE') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ $t('KANBAN_SETTINGS.BOARDS_DESCRIPTION') }}
          </p>
        </div>
        <Button
          sm
          icon="i-lucide-plus"
          :label="$t('KANBAN_SETTINGS.CREATE_BOARD')"
          @click="createBoard"
        />
      </div>

      <div
        v-if="kanbanConfig?.boards?.length > 0"
        class="grid gap-3 md:gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
      >
        <div
          v-for="board in kanbanConfig.boards"
          :key="board.id"
          class="group relative flex min-h-[220px] flex-col gap-4 rounded-2xl border border-n-weak bg-n-surface-1 p-4 transition-colors hover:border-n-brand"
        >
          <div
            v-if="board.isDefault"
            class="absolute right-4 top-4 inline-flex items-center rounded-full bg-n-brand/10 px-2.5 py-1 text-xs font-medium text-n-brand"
          >
            {{ $t('KANBAN_SETTINGS.DEFAULT') }}
          </div>

          <div class="flex items-start gap-2 md:gap-3">
            <div
              class="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl bg-n-brand/10"
            >
              <i
                class="i-lucide-kanban-square text-base md:text-lg text-n-brand"
              />
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="truncate text-sm font-semibold text-n-slate-12 md:text-base">
                {{ board.name }}
              </h3>
              <p
                v-if="board.description"
                class="mt-1 line-clamp-2 text-sm text-n-slate-11"
              >
                {{ board.description }}
              </p>
            </div>
          </div>

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
              {{ `+${board.stages.length - 5}` }}
            </div>
          </div>

          <div class="mt-auto flex items-center justify-between border-t border-n-weak pt-3">
            <span class="text-xs font-medium text-n-slate-10">
              {{ `${board.stages?.length || 0} ${$t('KANBAN_SETTINGS.STAGES')}` }}
            </span>

            <div class="flex items-center gap-1">
              <Button
                sm
                ghost
                slate
                icon="i-lucide-pencil-line"
                class="!px-2.5"
                :label="$t('KANBAN_SETTINGS.EDIT')"
                @click="editBoard(board)"
              />
              <button
                class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-n-brand transition-colors hover:bg-n-brand/10"
                :title="$t('KANBAN_SETTINGS.DUPLICATE')"
                @click="duplicateBoard(board)"
              >
                <i class="i-lucide-copy" />
              </button>
              <button
                class="inline-flex h-8 w-8 items-center justify-center rounded-lg text-n-ruby-11 transition-colors hover:bg-n-ruby-9/10"
                :title="$t('KANBAN_SETTINGS.DELETE')"
                @click="deleteBoard(board.id)"
              >
                <i class="i-lucide-trash-2" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <EmptyStateLayout
        v-else
        :title="$t('KANBAN_SETTINGS.NO_BOARDS')"
        :subtitle="$t('KANBAN_SETTINGS.NO_BOARDS_DESCRIPTION')"
      >
        <template #empty-state-item>
          <div
            class="mx-auto flex w-full max-w-md flex-col items-center justify-center rounded-2xl border border-dashed border-n-weak bg-n-surface-1 px-6 py-10 text-center"
          >
            <div
              class="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-n-brand/10 text-n-brand"
            >
              <i class="i-lucide-kanban-square text-3xl" />
            </div>
            <p class="max-w-sm text-sm text-n-slate-11">
              {{ $t('KANBAN_SETTINGS.NO_BOARDS_DESCRIPTION') }}
            </p>
          </div>
        </template>
        <template #actions>
          <Button
            icon="i-lucide-plus"
            :label="$t('KANBAN_SETTINGS.CREATE_FIRST_BOARD')"
            @click="createBoard"
          />
        </template>
      </EmptyStateLayout>

      <KanbanTemplates
        v-if="showTemplates"
        :show="showTemplates"
        @select-template="createFromTemplate"
        @close="
          showTemplates = false;
          createBlankBoard();
        "
      />
    </div>

    <KanbanBoardEditor
      v-if="showEditor"
      :board="selectedBoard"
      @save="saveBoard"
      @close="closeEditor"
    />
  </SettingsLayout>
</template>
