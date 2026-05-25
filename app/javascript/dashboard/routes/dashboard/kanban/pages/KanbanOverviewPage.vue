<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const { t } = useI18n();

const boards = computed(() => store.getters['kanban/getBoards'] || []);
const canManageBoards = computed(
  () =>
    store.getters.getCurrentRole === 'administrator' &&
    store.getters.getCurrentCustomRoleId === null
);

const totalStages = computed(() =>
  boards.value.reduce((sum, board) => sum + (board.stages?.length || 0), 0)
);

const defaultBoard = computed(
  () => boards.value.find(board => board.isDefault) || boards.value[0] || null
);

const automationCount = computed(() =>
  boards.value.filter(
    board =>
      board.webhook_url ||
      (board.auto_assign_inboxes && board.auto_assign_inboxes.length > 0) ||
      board.enable_round_robin
  ).length
);

const spotlightBoards = computed(() => boards.value.slice(0, 3));
</script>

<template>
  <div class="flex h-full w-full min-h-0 min-w-0 flex-1 flex-col overflow-y-auto bg-n-slate-2 px-4 py-5 md:px-6 md:py-6">
    <div class="mx-auto flex w-full max-w-7xl flex-col gap-6">
      <section class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6 md:p-8">
        <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="max-w-3xl space-y-3">
            <p class="text-sm font-semibold uppercase tracking-[0.18em] text-n-brand">
              {{ t('KANBAN.NAV.OVERVIEW') }}
            </p>
            <h1 class="text-3xl font-semibold tracking-tight text-n-slate-12 md:text-4xl">
              {{ t('KANBAN.OVERVIEW.TITLE') }}
            </h1>
            <p class="text-base text-n-slate-11 md:text-lg">
              {{ t('KANBAN.OVERVIEW.DESCRIPTION') }}
            </p>
          </div>

          <div class="flex flex-wrap gap-3">
            <router-link :to="{ name: 'kanban_funnels' }">
              <Button sm slate outline icon="i-lucide-panels-top-left" :label="t('KANBAN.NAV.FUNNELS')" />
            </router-link>
            <router-link v-if="canManageBoards" :to="{ name: 'kanban_board_new' }">
              <Button sm blue solid icon="i-lucide-plus" :label="t('KANBAN.NAV.NEW_FUNNEL')" />
            </router-link>
          </div>
        </div>
      </section>

      <section class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div class="rounded-3xl border border-n-weak bg-n-surface-1 p-5">
          <p class="text-sm text-n-slate-11">{{ t('KANBAN.OVERVIEW.TOTAL_FUNNELS') }}</p>
          <p class="mt-4 text-3xl font-semibold text-n-slate-12">{{ boards.length }}</p>
        </div>
        <div class="rounded-3xl border border-n-weak bg-n-surface-1 p-5">
          <p class="text-sm text-n-slate-11">{{ t('KANBAN.OVERVIEW.TOTAL_STAGES') }}</p>
          <p class="mt-4 text-3xl font-semibold text-n-slate-12">{{ totalStages }}</p>
        </div>
        <div class="rounded-3xl border border-n-weak bg-n-surface-1 p-5">
          <p class="text-sm text-n-slate-11">{{ t('KANBAN.OVERVIEW.DEFAULT_FUNNEL') }}</p>
          <p class="mt-4 truncate text-xl font-semibold text-n-slate-12">
            {{ defaultBoard?.name || '—' }}
          </p>
        </div>
        <div class="rounded-3xl border border-n-weak bg-n-surface-1 p-5">
          <p class="text-sm text-n-slate-11">{{ t('KANBAN.OVERVIEW.AUTOMATIONS') }}</p>
          <p class="mt-4 text-3xl font-semibold text-n-slate-12">{{ automationCount }}</p>
        </div>
      </section>

      <section v-if="spotlightBoards.length" class="grid gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(0,0.8fr)]">
        <div class="rounded-[28px] border border-n-weak bg-n-surface-1 p-5 md:p-6">
          <div class="flex items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ t('KANBAN.OVERVIEW.SPOTLIGHT_TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('KANBAN.OVERVIEW.SPOTLIGHT_DESCRIPTION') }}
              </p>
            </div>
            <router-link :to="{ name: 'kanban_funnels' }">
              <Button sm slate outline icon="i-lucide-arrow-right" :label="t('KANBAN.OVERVIEW.SEE_ALL')" />
            </router-link>
          </div>

          <div class="mt-5 grid gap-4 lg:grid-cols-3">
            <router-link
              v-for="board in spotlightBoards"
              :key="board.id"
              :to="{ name: 'kanban_board', params: { boardId: board.id } }"
              class="group rounded-3xl border border-n-weak bg-n-slate-1 p-4 transition-colors hover:border-n-brand hover:bg-n-brand/5"
            >
              <div class="flex items-center justify-between gap-3">
                <h3 class="truncate text-base font-semibold text-n-slate-12">
                  {{ board.name }}
                </h3>
                <span v-if="board.isDefault" class="rounded-full bg-n-brand/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-n-brand">
                  {{ t('KANBAN.NAV.DEFAULT') }}
                </span>
              </div>
              <p class="mt-2 line-clamp-2 min-h-[2.75rem] text-sm text-n-slate-11">
                {{ board.description || t('KANBAN.OVERVIEW.NO_DESCRIPTION') }}
              </p>
              <div class="mt-4 flex flex-wrap gap-2">
                <span
                  v-for="stage in board.stages?.slice(0, 4) || []"
                  :key="stage.id"
                  class="inline-flex items-center gap-1 rounded-full border border-n-weak bg-n-surface-1 px-2.5 py-1 text-xs font-medium text-n-slate-11"
                >
                  <span class="h-2 w-2 rounded-full" :style="{ backgroundColor: stage.color }" />
                  {{ stage.name }}
                </span>
              </div>
            </router-link>
          </div>
        </div>

        <div class="rounded-[28px] border border-n-weak bg-n-surface-1 p-5 md:p-6">
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ t('KANBAN.OVERVIEW.QUICK_ACTIONS') }}
          </h2>
          <div class="mt-5 space-y-3">
            <router-link :to="{ name: 'kanban_funnels' }" class="flex items-center justify-between rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12 transition-colors hover:border-n-brand hover:bg-n-brand/5">
              <span>{{ t('KANBAN.OVERVIEW.MANAGE_FUNNELS') }}</span>
              <i class="i-lucide-arrow-right" />
            </router-link>
            <router-link v-if="defaultBoard" :to="{ name: 'kanban_board', params: { boardId: defaultBoard.id } }" class="flex items-center justify-between rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12 transition-colors hover:border-n-brand hover:bg-n-brand/5">
              <span>{{ t('KANBAN.OVERVIEW.OPEN_DEFAULT') }}</span>
              <i class="i-lucide-arrow-right" />
            </router-link>
            <router-link v-if="canManageBoards" :to="{ name: 'kanban_board_new' }" class="flex items-center justify-between rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12 transition-colors hover:border-n-brand hover:bg-n-brand/5">
              <span>{{ t('KANBAN.NAV.NEW_FUNNEL') }}</span>
              <i class="i-lucide-plus" />
            </router-link>
            <router-link v-if="canManageBoards" :to="{ name: 'kanban_funnels' }" class="flex items-center justify-between rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12 transition-colors hover:border-n-brand hover:bg-n-brand/5">
              <span>{{ t('KANBAN.NAV.FUNNELS') }}</span>
              <i class="i-lucide-list-filter" />
            </router-link>
          </div>
        </div>
      </section>

      <section v-else class="rounded-[28px] border border-dashed border-n-weak bg-n-surface-1 p-10 text-center">
        <div class="mx-auto flex max-w-xl flex-col items-center gap-4">
          <div class="flex h-16 w-16 items-center justify-center rounded-3xl bg-n-brand/10 text-n-blue-11">
            <i class="i-lucide-kanban-square text-3xl" />
          </div>
          <h2 class="text-2xl font-semibold text-n-slate-12">
            {{ t('KANBAN.OVERVIEW.EMPTY_TITLE') }}
          </h2>
          <p class="text-base text-n-slate-11">
            {{ t('KANBAN.OVERVIEW.EMPTY_DESCRIPTION') }}
          </p>
          <router-link v-if="canManageBoards" :to="{ name: 'kanban_board_new' }">
            <Button blue solid icon="i-lucide-plus" :label="t('KANBAN.NAV.NEW_FUNNEL')" />
          </router-link>
        </div>
      </section>
    </div>
  </div>
</template>