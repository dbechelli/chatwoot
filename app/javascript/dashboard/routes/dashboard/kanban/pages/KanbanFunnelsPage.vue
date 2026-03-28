<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const boards = computed(() => store.getters['kanban/getBoards'] || []);
const uiFlags = computed(() => store.getters['kanban/getUIFlags'] || {});
const canManageBoards = computed(
  () =>
    store.getters.getCurrentRole === 'administrator' &&
    store.getters.getCurrentCustomRoleId === null
);

const openBoard = boardId => {
  router.push({ name: 'kanban_board', params: { boardId } });
};

const editBoard = boardId => {
  router.push({ name: 'kanban_board_edit', params: { boardId } });
};

const duplicateBoard = async boardId => {
  try {
    await window.axios.post(
      `/api/v1/accounts/${store.getters.getCurrentAccountId}/kanban_settings/boards/${boardId}/duplicate`
    );
    await store.dispatch('kanban/fetch');
    useAlert(t('KANBAN_SETTINGS.DUPLICATE_SUCCESS'));
  } catch {
    useAlert(t('KANBAN_SETTINGS.DUPLICATE_ERROR'));
  }
};

const deleteBoard = async boardId => {
  if (!confirm(t('KANBAN_SETTINGS.CONFIRM_DELETE'))) return;

  try {
    await store.dispatch('kanban/delete', boardId);
    useAlert(t('KANBAN_SETTINGS.DELETE_SUCCESS'));
    await store.dispatch('kanban/fetch');
  } catch {
    useAlert(t('KANBAN_SETTINGS.DELETE_ERROR'));
  }
};
</script>

<template>
  <div class="flex h-full flex-col overflow-y-auto bg-n-slate-2 px-4 py-5 md:px-6 md:py-6">
    <div class="mx-auto flex w-full max-w-7xl flex-col gap-6">
      <section class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6 md:p-8">
        <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="max-w-3xl space-y-3">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-n-brand">
              {{ t('KANBAN.NAV.FUNNELS') }}
            </p>
            <h1 class="text-3xl font-semibold tracking-tight text-n-slate-12 md:text-4xl">
              {{ t('KANBAN.FUNNELS.TITLE') }}
            </h1>
            <p class="text-base text-n-slate-11 md:text-lg">
              {{ t('KANBAN.FUNNELS.DESCRIPTION') }}
            </p>
          </div>

          <router-link v-if="canManageBoards" :to="{ name: 'kanban_board_new' }">
            <Button sm blue solid icon="i-lucide-plus" :label="t('KANBAN.NAV.NEW_FUNNEL')" />
          </router-link>
        </div>
      </section>

      <section v-if="boards.length" class="grid gap-4 xl:grid-cols-2 2xl:grid-cols-3">
        <article
          v-for="board in boards"
          :key="board.id"
          class="flex flex-col rounded-[28px] border border-n-weak bg-n-surface-1 p-5 transition-colors hover:border-n-brand/60"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <h2 class="truncate text-lg font-semibold text-n-slate-12">
                  {{ board.name }}
                </h2>
                <span v-if="board.isDefault" class="rounded-full bg-n-brand/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-n-brand">
                  {{ t('KANBAN.NAV.DEFAULT') }}
                </span>
              </div>
              <p class="mt-2 min-h-[3rem] text-sm text-n-slate-11">
                {{ board.description || t('KANBAN.FUNNELS.NO_DESCRIPTION') }}
              </p>
            </div>

            <button
              v-if="canManageBoards"
              class="inline-flex h-9 w-9 items-center justify-center rounded-xl text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-slate-12"
              :title="t('KANBAN.FUNNELS.EDIT_FUNNEL')"
              @click="editBoard(board.id)"
            >
              <i class="i-lucide-pencil-line" />
            </button>
          </div>

          <div class="mt-5 flex flex-wrap gap-2">
            <span
              v-for="stage in board.stages?.slice(0, 6) || []"
              :key="stage.id"
              class="inline-flex items-center gap-1 rounded-full border border-n-weak bg-n-slate-1 px-2.5 py-1 text-xs font-medium text-n-slate-11"
            >
              <span class="h-2 w-2 rounded-full" :style="{ backgroundColor: stage.color }" />
              {{ stage.name }}
            </span>
          </div>

          <div class="mt-5 flex items-center justify-between gap-3 border-t border-n-weak pt-4">
            <span class="text-sm font-medium text-n-slate-11">
              {{ board.stages?.length || 0 }} {{ t('KANBAN.FUNNELS.STAGE_COUNT') }}
            </span>

            <div class="flex items-center gap-2">
              <Button sm slate outline icon="i-lucide-arrow-right" :label="t('KANBAN.FUNNELS.OPEN_FUNNEL')" @click="openBoard(board.id)" />
              <button
                v-if="canManageBoards"
                class="inline-flex h-9 w-9 items-center justify-center rounded-xl text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-slate-12"
                :title="t('KANBAN.FUNNELS.DUPLICATE_FUNNEL')"
                @click="duplicateBoard(board.id)"
              >
                <i class="i-lucide-copy" />
              </button>
              <button
                v-if="canManageBoards"
                class="inline-flex h-9 w-9 items-center justify-center rounded-xl text-n-ruby-11 transition-colors hover:bg-n-ruby-3/40"
                :title="t('KANBAN.FUNNELS.DELETE_FUNNEL')"
                @click="deleteBoard(board.id)"
              >
                <i class="i-lucide-trash-2" />
              </button>
            </div>
          </div>
        </article>
      </section>

      <section v-else class="rounded-[28px] border border-dashed border-n-weak bg-n-surface-1 p-10 text-center">
        <div class="mx-auto flex max-w-xl flex-col items-center gap-4">
          <div class="flex h-16 w-16 items-center justify-center rounded-3xl bg-n-brand/10 text-n-blue-11">
            <i class="i-lucide-panels-top-left text-3xl" />
          </div>
          <h2 class="text-2xl font-semibold text-n-slate-12">
            {{ t('KANBAN.FUNNELS.EMPTY_TITLE') }}
          </h2>
          <p class="text-base text-n-slate-11">
            {{ t('KANBAN.FUNNELS.EMPTY_DESCRIPTION') }}
          </p>
          <router-link v-if="canManageBoards" :to="{ name: 'kanban_board_new' }">
            <Button blue solid icon="i-lucide-plus" :label="t('KANBAN.NAV.NEW_FUNNEL')" />
          </router-link>
        </div>
      </section>

      <div v-if="uiFlags.isFetching" class="text-sm text-n-slate-11">
        {{ t('KANBAN.LOADING') }}
      </div>
    </div>
  </div>
</template>