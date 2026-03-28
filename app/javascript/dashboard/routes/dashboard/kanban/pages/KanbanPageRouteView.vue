<script setup>
import { computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const route = useRoute();
const { t } = useI18n();

const boards = computed(() => store.getters['kanban/getBoards'] || []);
const uiFlags = computed(() => store.getters['kanban/getUIFlags'] || {});
const canManageBoards = computed(
  () =>
    store.getters.getCurrentRole === 'administrator' &&
    store.getters.getCurrentCustomRoleId === null
);

const isActive = routeNames => routeNames.includes(route.name);

onMounted(() => {
  store.dispatch('kanban/fetch');
});
</script>

<template>
  <div class="flex h-full min-h-0 flex-col bg-n-slate-2 lg:flex-row">
    <aside class="w-full border-b border-n-weak bg-n-surface-1 lg:w-72 lg:flex-shrink-0 lg:border-b-0 lg:border-r">
      <div class="flex items-center justify-between gap-3 border-b border-n-weak px-4 py-4">
        <div class="min-w-0">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-2xl bg-n-brand/10 text-n-blue-11">
              <i class="i-lucide-kanban-square text-xl" />
            </div>
            <div class="min-w-0">
              <h1 class="truncate text-base font-semibold text-n-slate-12">
                {{ t('SIDEBAR.KANBAN') }}
              </h1>
              <p class="truncate text-xs text-n-slate-11">
                {{ t('KANBAN.NAV.DESCRIPTION') }}
              </p>
            </div>
          </div>
        </div>

        <router-link v-if="canManageBoards" :to="{ name: 'kanban_board_new' }">
          <Button sm blue solid icon="i-lucide-plus" :label="t('KANBAN.NAV.NEW_FUNNEL')" />
        </router-link>
      </div>

      <div class="flex flex-col gap-5 px-3 py-4">
        <div class="flex gap-2 overflow-x-auto pb-1 lg:flex-col lg:overflow-visible">
          <router-link
            :to="{ name: 'kanban_overview' }"
            class="flex min-w-fit items-center gap-2 rounded-2xl px-3 py-2 text-sm font-medium transition-colors lg:min-w-0"
            :class="
              isActive(['kanban', 'kanban_overview'])
                ? 'bg-n-brand/10 text-n-brand'
                : 'text-n-slate-11 hover:bg-n-slate-2 hover:text-n-slate-12'
            "
          >
            <i class="i-lucide-layout-dashboard text-base" />
            <span>{{ t('KANBAN.NAV.OVERVIEW') }}</span>
          </router-link>

          <router-link
            :to="{ name: 'kanban_funnels' }"
            class="flex min-w-fit items-center gap-2 rounded-2xl px-3 py-2 text-sm font-medium transition-colors lg:min-w-0"
            :class="
              isActive(['kanban_funnels', 'kanban_board', 'kanban_board_new', 'kanban_board_edit'])
                ? 'bg-n-brand/10 text-n-brand'
                : 'text-n-slate-11 hover:bg-n-slate-2 hover:text-n-slate-12'
            "
          >
            <i class="i-lucide-panels-top-left text-base" />
            <span>{{ t('KANBAN.NAV.FUNNELS') }}</span>
          </router-link>
        </div>

        <div class="space-y-2">
          <div class="flex items-center justify-between px-1">
            <p class="text-xs font-semibold uppercase tracking-wide text-n-slate-10">
              {{ t('KANBAN.NAV.FUNNELS') }}
            </p>
            <span class="rounded-full bg-n-slate-2 px-2 py-0.5 text-xs font-medium text-n-slate-11">
              {{ boards.length }}
            </span>
          </div>

          <div v-if="uiFlags.isFetching" class="space-y-2 px-1">
            <div
              v-for="index in 3"
              :key="index"
              class="h-11 animate-pulse rounded-2xl bg-n-slate-2"
            />
          </div>

          <div v-else-if="boards.length" class="space-y-1">
            <router-link
              v-for="board in boards"
              :key="board.id"
              :to="{ name: 'kanban_board', params: { boardId: board.id } }"
              class="flex items-center gap-3 rounded-2xl px-3 py-2.5 text-sm transition-colors"
              :class="
                route.params.boardId === String(board.id)
                  ? 'bg-n-slate-12 text-white'
                  : 'text-n-slate-12 hover:bg-n-slate-2'
              "
            >
              <span
                class="h-2.5 w-2.5 rounded-full"
                :style="{ backgroundColor: board.stages?.[0]?.color || '#3b82f6' }"
              />
              <span class="min-w-0 flex-1 truncate">{{ board.name }}</span>
              <span
                v-if="board.isDefault"
                class="rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide"
                :class="route.params.boardId === String(board.id) ? 'bg-white/15 text-white' : 'bg-n-brand/10 text-n-brand'"
              >
                {{ t('KANBAN.NAV.DEFAULT') }}
              </span>
            </router-link>
          </div>

          <div v-else class="rounded-2xl border border-dashed border-n-weak bg-n-slate-1 px-4 py-5 text-sm text-n-slate-11">
            {{ t('KANBAN.NAV.NO_FUNNELS') }}
          </div>
        </div>

        <router-link
          v-if="canManageBoards"
          :to="{ name: 'kanban_settings' }"
          class="inline-flex items-center gap-2 rounded-2xl px-3 py-2 text-sm font-medium text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-slate-12"
        >
          <i class="i-lucide-settings-2 text-base" />
          <span>{{ t('KANBAN.NAV.SETTINGS') }}</span>
        </router-link>
      </div>
    </aside>

    <section class="min-w-0 flex-1 overflow-hidden">
      <router-view />
    </section>
  </div>
</template>