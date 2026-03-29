<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t, tm } = useI18n();

const isEditMode = computed(() => !!route.params.boardId);
const boardId = computed(() => route.params.boardId);
const boardFromStore = computed(() =>
  boardId.value ? store.getters['kanban/getBoardById'](boardId.value) : null
);

const agents = computed(() => store.getters['agents/getAgents']);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const conversationAttributes = computed(
  () => store.getters['attributes/getConversationAttributes']
);

const showAdvanced = ref(false);
const enableValue = ref(true);
const step = ref(isEditMode.value ? 'form' : 'templates');
const isSaving = ref(false);

const colorPresets = [
  { color: '#60a5fa', name: 'Blue' },
  { color: '#a78bfa', name: 'Purple' },
  { color: '#fbbf24', name: 'Amber' },
  { color: '#fb7185', name: 'Rose' },
  { color: '#34d399', name: 'Emerald' },
  { color: '#f87171', name: 'Red' },
  { color: '#818cf8', name: 'Indigo' },
  { color: '#94a3b8', name: 'Slate' },
];

const templateDefinitions = [
  { id: 'blank', key: null, icon: 'i-lucide-layout-template' },
  { id: 'sales_pipeline', key: 'SALES_PIPELINE', icon: 'i-lucide-badge-dollar-sign' },
  { id: 'customer_support', key: 'CUSTOMER_SUPPORT', icon: 'i-lucide-headphones' },
  { id: 'recruitment', key: 'RECRUITMENT', icon: 'i-lucide-users' },
  { id: 'onboarding', key: 'ONBOARDING', icon: 'i-lucide-rocket' },
  { id: 'project_management', key: 'PROJECT_MANAGEMENT', icon: 'i-lucide-folder-kanban' },
];

const createBlankBoard = () => ({
  name: '',
  description: '',
  customAttributeKey: '',
  valueAttributeKey: 'deal_value',
  isDefault: false,
  webhook_url: '',
  enable_round_robin: false,
  agent_ids: [],
  visible_attributes: [],
  auto_assign_inboxes: [],
  auto_assign_stage_id: '',
  stages: [
    {
      id: `stage-${Date.now()}`,
      name: t('KANBAN_SETTINGS.NEW_STAGE'),
      color: '#60a5fa',
      order: 1,
      wipLimit: null,
    },
  ],
});

const localBoard = ref(createBlankBoard());

const normalizeBoard = board => ({
  ...createBlankBoard(),
  ...JSON.parse(JSON.stringify(board)),
  agent_ids: board.agent_ids || [],
  visible_attributes: board.visible_attributes || [],
  auto_assign_inboxes: board.auto_assign_inboxes || [],
  auto_assign_stage_id: board.auto_assign_stage_id || '',
  enable_round_robin: board.enable_round_robin || false,
  webhook_url: board.webhook_url || '',
  stages: (board.stages || [])
    .slice()
    .sort((left, right) => (left.order || 0) - (right.order || 0)),
});

const applyTemplate = template => {
  if (!template.key) {
    localBoard.value = createBlankBoard();
    enableValue.value = true;
    step.value = 'form';
    return;
  }

  const baseKey = `KANBAN_SETTINGS.TEMPLATES.${template.key}`;
  const stagesKey = `${baseKey}.STAGES`;
  const stageMap = tm(stagesKey) || {};
  const stageKeys = Object.keys(stageMap);

  localBoard.value = {
    ...createBlankBoard(),
    name: t(`${baseKey}.NAME`),
    description: t(`${baseKey}.DESCRIPTION`),
    customAttributeKey: `${template.id}_status`,
    valueAttributeKey: 'deal_value',
    stages: stageKeys.map((key, index) => ({
      id: key.toLowerCase(),
      name: t(`${stagesKey}.${key}`),
      color: colorPresets[index % colorPresets.length].color,
      order: index + 1,
      wipLimit: null,
    })),
  };
  enableValue.value = true;
  step.value = 'form';
};

watch(
  boardFromStore,
  board => {
    if (!isEditMode.value || !board) return;
    localBoard.value = normalizeBoard(board);
    enableValue.value = !!board.valueAttributeKey;
    step.value = 'form';
  },
  { immediate: true }
);

watch(
  () => localBoard.value.name,
  newName => {
    if (isEditMode.value || showAdvanced.value || !newName) return;

    const slug = newName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');

    localBoard.value.customAttributeKey = slug ? `${slug}_status` : '';
  }
);

watch(enableValue, enabled => {
  if (!enabled) {
    localBoard.value.valueAttributeKey = '';
  } else if (!localBoard.value.valueAttributeKey) {
    localBoard.value.valueAttributeKey = 'deal_value';
  }
});

const canSave = computed(() => {
  return (
    localBoard.value.name &&
    localBoard.value.customAttributeKey &&
    localBoard.value.stages.length > 0 &&
    localBoard.value.stages.every(stage => stage.name)
  );
});

const addStage = () => {
  localBoard.value.stages.push({
    id: `stage-${Date.now()}`,
    name: t('KANBAN_SETTINGS.NEW_STAGE'),
    color: colorPresets[localBoard.value.stages.length % colorPresets.length].color,
    order: localBoard.value.stages.length + 1,
    wipLimit: null,
  });
};

const reindexStages = () => {
  localBoard.value.stages.forEach((stage, index) => {
    stage.order = index + 1;
  });
};

const moveStage = (index, direction) => {
  const nextIndex = index + direction;
  if (nextIndex < 0 || nextIndex >= localBoard.value.stages.length) return;
  const stages = [...localBoard.value.stages];
  [stages[index], stages[nextIndex]] = [stages[nextIndex], stages[index]];
  localBoard.value.stages = stages;
  reindexStages();
};

const removeStage = index => {
  localBoard.value.stages.splice(index, 1);
  reindexStages();
};

const toggleAgent = agentId => {
  const ids = localBoard.value.agent_ids;
  localBoard.value.agent_ids = ids.includes(agentId)
    ? ids.filter(id => id !== agentId)
    : [...ids, agentId];
};

const toggleAttribute = key => {
  const attributes = localBoard.value.visible_attributes;
  localBoard.value.visible_attributes = attributes.includes(key)
    ? attributes.filter(value => value !== key)
    : [...attributes, key];
};

const resolveSaveErrorMessage = error => {
  if (error?.code === 'kanban_schema_missing') {
    return t('KANBAN_SETTINGS.SCHEMA_MISSING');
  }

  return error?.message || t('KANBAN_SETTINGS.SAVE_ERROR');
};

const handleSave = async () => {
  if (!canSave.value) return;

  isSaving.value = true;
  const payload = {
    ...localBoard.value,
    valueAttributeKey: enableValue.value ? localBoard.value.valueAttributeKey : '',
    stages: localBoard.value.stages.map((stage, index) => ({
      ...stage,
      order: index + 1,
    })),
  };

  try {
    let board;
    if (isEditMode.value) {
      board = await store.dispatch('kanban/update', {
        id: boardId.value,
        ...payload,
      });
      useAlert(t('KANBAN_SETTINGS.BOARD_UPDATED'));
    } else {
      board = await store.dispatch('kanban/create', payload);
      useAlert(t('KANBAN_SETTINGS.BOARD_CREATED'));
    }

    await store.dispatch('kanban/fetch');
    router.push({ name: 'kanban_board', params: { boardId: board.id } });
  } catch (error) {
    useAlert(resolveSaveErrorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  await Promise.all([
    store.dispatch('kanban/fetch'),
    store.dispatch('agents/get'),
    store.dispatch('attributes/get'),
    store.dispatch('inboxes/get'),
  ]);

  if (!isEditMode.value) {
    localBoard.value = createBlankBoard();
    enableValue.value = true;
  }
});
</script>

<template>
  <div class="flex h-full flex-col overflow-y-auto bg-n-slate-2 px-4 py-5 md:px-6 md:py-6">
    <div class="mx-auto flex w-full max-w-7xl flex-col gap-6">
      <section class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6 md:p-8">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div class="space-y-3">
            <router-link :to="{ name: 'kanban_funnels' }" class="inline-flex items-center gap-2 text-sm font-medium text-n-slate-11 hover:text-n-slate-12">
              <i class="i-lucide-arrow-left" />
              {{ t('KANBAN.EDITOR.BACK_TO_FUNNELS') }}
            </router-link>
            <div>
              <h1 class="text-3xl font-semibold tracking-tight text-n-slate-12 md:text-4xl">
                {{ isEditMode ? t('KANBAN.EDITOR.EDIT_TITLE') : t('KANBAN.EDITOR.CREATE_TITLE') }}
              </h1>
              <p class="mt-2 text-base text-n-slate-11 md:text-lg">
                {{ t('KANBAN.EDITOR.DESCRIPTION') }}
              </p>
            </div>
          </div>

          <div class="flex flex-wrap gap-3">
            <Button sm slate outline :label="t('KANBAN_SETTINGS.CANCEL')" @click="router.push({ name: isEditMode ? 'kanban_board' : 'kanban_funnels', params: isEditMode ? { boardId } : {} })" />
            <Button sm blue solid :label="t('KANBAN_SETTINGS.SAVE')" :disabled="!canSave" :is-loading="isSaving" @click="handleSave" />
          </div>
        </div>
      </section>

      <section v-if="!isEditMode && step === 'templates'" class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6 md:p-8">
        <div class="max-w-2xl space-y-2">
          <h2 class="text-2xl font-semibold text-n-slate-12">
            {{ t('KANBAN.EDITOR.TEMPLATE_TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11 md:text-base">
            {{ t('KANBAN.EDITOR.TEMPLATE_DESCRIPTION') }}
          </p>
        </div>

        <div class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <button
            v-for="template in templateDefinitions"
            :key="template.id"
            class="flex min-h-[180px] flex-col rounded-[24px] border border-n-weak bg-n-slate-1 p-5 text-left transition-colors hover:border-n-brand hover:bg-n-brand/5"
            @click="applyTemplate(template)"
          >
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-n-surface-1 text-n-slate-12">
              <i :class="template.icon" class="text-2xl" />
            </div>
            <h3 class="mt-5 text-xl font-semibold text-n-slate-12">
              {{ template.key ? t(`KANBAN_SETTINGS.TEMPLATES.${template.key}.NAME`) : t('KANBAN.EDITOR.BLANK_TITLE') }}
            </h3>
            <p class="mt-3 text-sm text-n-slate-11 md:text-base">
              {{ template.key ? t(`KANBAN_SETTINGS.TEMPLATES.${template.key}.DESCRIPTION`) : t('KANBAN.EDITOR.BLANK_DESCRIPTION') }}
            </p>
          </button>
        </div>
      </section>

      <div v-else class="grid gap-6 xl:grid-cols-[minmax(0,1.15fr)_minmax(320px,0.85fr)]">
        <section class="space-y-6">
          <article class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <div class="flex items-center justify-between gap-3">
              <h2 class="text-xl font-semibold text-n-slate-12">
                {{ t('KANBAN_SETTINGS.BASIC_CONFIG') }}
              </h2>
              <Button v-if="!isEditMode" sm slate outline icon="i-lucide-undo-2" :label="t('KANBAN.EDITOR.BACK_TO_TEMPLATES')" @click="step = 'templates'" />
            </div>

            <div class="mt-6 grid gap-4 md:grid-cols-2">
              <div class="space-y-2">
                <label class="block text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN_SETTINGS.BOARD_NAME') }} <span class="text-red-500">{{ t('KANBAN_SETTINGS.REQUIRED') }}</span>
                </label>
                <input v-model="localBoard.name" type="text" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.BOARD_NAME_PLACEHOLDER')" />
              </div>

              <div class="space-y-2">
                <label class="block text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN_SETTINGS.BOARD_DESCRIPTION') }}
                </label>
                <textarea v-model="localBoard.description" rows="4" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.BOARD_DESCRIPTION_PLACEHOLDER')" />
              </div>

              <div class="space-y-2">
                <label class="block text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_KEY') }} <span class="text-red-500">{{ t('KANBAN_SETTINGS.REQUIRED') }}</span>
                </label>
                <input v-model="localBoard.customAttributeKey" type="text" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_PLACEHOLDER')" />
                <p class="text-xs text-n-slate-11">{{ t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_HELP') }}</p>
              </div>

              <div class="space-y-3">
                <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                  <input v-model="enableValue" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                  <span>{{ t('KANBAN_SETTINGS.ENABLE_VALUE') }}</span>
                </label>
                <p class="text-xs text-n-slate-11">{{ t('KANBAN_SETTINGS.ENABLE_VALUE_HELP') }}</p>
                <div v-if="enableValue" class="space-y-2">
                  <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.VALUE_ATTRIBUTE_KEY') }}</label>
                  <input v-model="localBoard.valueAttributeKey" type="text" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.VALUE_ATTRIBUTE_PLACEHOLDER')" />
                </div>
              </div>
            </div>
          </article>

          <article class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-xl font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.STAGES') }}</h2>
                <p class="mt-1 text-sm text-n-slate-11">{{ t('KANBAN.EDITOR.STAGES_DESCRIPTION') }}</p>
              </div>
              <Button sm blue solid icon="i-lucide-plus" :label="t('KANBAN_SETTINGS.ADD_STAGE')" @click="addStage" />
            </div>

            <div class="mt-6 space-y-3">
              <div v-for="(stage, index) in localBoard.stages" :key="stage.id" class="rounded-3xl border border-n-weak bg-n-slate-1 p-4">
                <div class="grid gap-4 lg:grid-cols-[auto_minmax(0,1fr)_160px_130px_auto] lg:items-end">
                  <div class="flex gap-1">
                    <button class="inline-flex h-10 w-10 items-center justify-center rounded-2xl text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-slate-12 disabled:opacity-40" :disabled="index === 0" @click="moveStage(index, -1)">
                      <i class="i-lucide-chevron-up" />
                    </button>
                    <button class="inline-flex h-10 w-10 items-center justify-center rounded-2xl text-n-slate-11 transition-colors hover:bg-n-slate-2 hover:text-n-slate-12 disabled:opacity-40" :disabled="index === localBoard.stages.length - 1" @click="moveStage(index, 1)">
                      <i class="i-lucide-chevron-down" />
                    </button>
                  </div>

                  <div class="space-y-2">
                    <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.STAGE_NAME') }}</label>
                    <input v-model="stage.name" type="text" class="w-full rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.STAGE_NAME_PLACEHOLDER')" />
                  </div>

                  <div class="space-y-2">
                    <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.COLOR') }}</label>
                    <select v-model="stage.color" class="w-full rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                      <option v-for="preset in colorPresets" :key="preset.color" :value="preset.color">{{ preset.name }}</option>
                    </select>
                  </div>

                  <div class="space-y-2">
                    <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.WIP_LIMIT') }}</label>
                    <input v-model.number="stage.wipLimit" type="number" min="0" class="w-full rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.NO_LIMIT')" />
                  </div>

                  <button class="inline-flex h-11 w-11 items-center justify-center rounded-2xl text-n-ruby-11 transition-colors hover:bg-n-ruby-3/40" @click="removeStage(index)">
                    <i class="i-lucide-trash-2" />
                  </button>
                </div>
              </div>
            </div>
          </article>
        </section>

        <section class="space-y-6">
          <article class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <div class="flex items-center justify-between gap-3">
              <h2 class="text-xl font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.ADVANCED_CONFIG') }}</h2>
              <button class="inline-flex items-center gap-2 text-sm font-medium text-n-brand" @click="showAdvanced = !showAdvanced">
                <i :class="showAdvanced ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'" />
                {{ showAdvanced ? t('KANBAN.EDITOR.HIDE_ADVANCED') : t('KANBAN.EDITOR.SHOW_ADVANCED') }}
              </button>
            </div>

            <div class="mt-6 space-y-5">
              <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                <input v-model="localBoard.isDefault" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                <span>{{ t('KANBAN_SETTINGS.SET_AS_DEFAULT') }}</span>
              </label>

              <div v-if="showAdvanced" class="space-y-4">
                <div class="space-y-2">
                  <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.WEBHOOK_URL') }}</label>
                  <input v-model="localBoard.webhook_url" type="url" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.WEBHOOK_PLACEHOLDER')" />
                  <p class="text-xs text-n-slate-11">{{ t('KANBAN_SETTINGS.WEBHOOK_HELP') }}</p>
                </div>

                <div class="space-y-3">
                  <p class="text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.INBOXES') }}</p>
                  <div class="grid gap-2 sm:grid-cols-2">
                    <label v-for="inbox in inboxes" :key="inbox.id" class="flex items-center gap-2 rounded-2xl border border-n-weak bg-n-slate-1 px-3 py-3 text-sm text-n-slate-12">
                      <input v-model="localBoard.auto_assign_inboxes" type="checkbox" :value="inbox.id" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                      <span class="truncate">{{ inbox.name }}</span>
                    </label>
                  </div>
                </div>

                <div class="space-y-2">
                  <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.INITIAL_STAGE') }}</label>
                  <select v-model="localBoard.auto_assign_stage_id" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                    <option value="">{{ t('KANBAN_SETTINGS.SELECT_STAGE') }}</option>
                    <option v-for="stage in localBoard.stages" :key="stage.id" :value="stage.id">{{ stage.name }}</option>
                  </select>
                </div>

                <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                  <input v-model="localBoard.enable_round_robin" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                  <span>{{ t('KANBAN_SETTINGS.ROUND_ROBIN') }}</span>
                </label>
              </div>
            </div>
          </article>

          <article class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <h2 class="text-xl font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.AGENTS') }}</h2>
            <div class="mt-5 grid gap-2 sm:grid-cols-2">
              <label v-for="agent in agents" :key="agent.id" class="flex items-center gap-2 rounded-2xl border border-n-weak bg-n-slate-1 px-3 py-3 text-sm text-n-slate-12">
                <input type="checkbox" :checked="localBoard.agent_ids.includes(agent.id)" class="rounded border-n-weak text-n-brand focus:ring-n-brand" @change="toggleAgent(agent.id)" />
                <span class="truncate">{{ agent.name }}</span>
              </label>
            </div>
          </article>

          <article v-if="conversationAttributes.length > 0" class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <h2 class="text-xl font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.VISIBLE_ATTRIBUTES') }}</h2>
            <div class="mt-5 grid gap-2 sm:grid-cols-2">
              <label v-for="attribute in conversationAttributes" :key="attribute.attributeKey" class="flex items-center gap-2 rounded-2xl border border-n-weak bg-n-slate-1 px-3 py-3 text-sm text-n-slate-12">
                <input type="checkbox" :checked="localBoard.visible_attributes.includes(attribute.attributeKey)" class="rounded border-n-weak text-n-brand focus:ring-n-brand" @change="toggleAttribute(attribute.attributeKey)" />
                <span class="truncate">{{ attribute.attributeDisplayName }}</span>
              </label>
            </div>
          </article>
        </section>
      </div>
    </div>
  </div>
</template>