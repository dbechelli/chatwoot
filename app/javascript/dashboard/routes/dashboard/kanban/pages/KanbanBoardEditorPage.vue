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

const automationTriggerOptions = [
  { value: 'message_created', labelKey: 'KANBAN_SETTINGS.RULE_TRIGGERS.MESSAGE_CREATED' },
  { value: 'conversation_created', labelKey: 'KANBAN_SETTINGS.RULE_TRIGGERS.CONVERSATION_CREATED' },
  { value: 'conversation_updated', labelKey: 'KANBAN_SETTINGS.RULE_TRIGGERS.CONVERSATION_UPDATED' },
  { value: 'task_overdue', labelKey: 'KANBAN_SETTINGS.RULE_TRIGGERS.TASK_OVERDUE' },
];

const automationFieldOptions = [
  { value: 'message.content', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.MESSAGE_CONTENT' },
  { value: 'message.message_type', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.MESSAGE_TYPE' },
  { value: 'conversation.inbox_id', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.INBOX' },
  { value: 'conversation.status', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.STATUS' },
  { value: 'conversation.priority', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.PRIORITY' },
  { value: 'conversation.labels', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.LABELS' },
  { value: 'conversation.assignee_id', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.ASSIGNEE' },
  { value: 'contact.phone_number', labelKey: 'KANBAN_SETTINGS.RULE_FIELDS.PHONE_NUMBER' },
];

const automationOperatorOptions = [
  { value: 'equals', labelKey: 'KANBAN_SETTINGS.RULE_OPERATORS.EQUALS' },
  { value: 'not_equals', labelKey: 'KANBAN_SETTINGS.RULE_OPERATORS.NOT_EQUALS' },
  { value: 'contains', labelKey: 'KANBAN_SETTINGS.RULE_OPERATORS.CONTAINS' },
  { value: 'contains_any', labelKey: 'KANBAN_SETTINGS.RULE_OPERATORS.CONTAINS_ANY' },
  { value: 'in', labelKey: 'KANBAN_SETTINGS.RULE_OPERATORS.IN' },
  { value: 'present', labelKey: 'KANBAN_SETTINGS.RULE_OPERATORS.PRESENT' },
];

const automationActionOptions = [
  { value: 'enter_board', labelKey: 'KANBAN_SETTINGS.RULE_ACTIONS.ENTER_BOARD' },
  { value: 'move_stage', labelKey: 'KANBAN_SETTINGS.RULE_ACTIONS.MOVE_STAGE' },
  { value: 'set_priority', labelKey: 'KANBAN_SETTINGS.RULE_ACTIONS.SET_PRIORITY' },
  { value: 'assign_agent', labelKey: 'KANBAN_SETTINGS.RULE_ACTIONS.ASSIGN_AGENT' },
  { value: 'add_label', labelKey: 'KANBAN_SETTINGS.RULE_ACTIONS.ADD_LABEL' },
  { value: 'send_webhook', labelKey: 'KANBAN_SETTINGS.RULE_ACTIONS.SEND_WEBHOOK' },
  { value: 'send_template', labelKey: 'KANBAN_SETTINGS.RULE_ACTIONS.SEND_TEMPLATE' },
];

const webhookSubscriptionOptions = [
  { value: 'card_created', labelKey: 'KANBAN_SETTINGS.WEBHOOK_EVENTS.CARD_CREATED' },
  { value: 'card_updated', labelKey: 'KANBAN_SETTINGS.WEBHOOK_EVENTS.CARD_UPDATED' },
  { value: 'stage_changed', labelKey: 'KANBAN_SETTINGS.WEBHOOK_EVENTS.STAGE_CHANGED' },
  { value: 'card_deleted', labelKey: 'KANBAN_SETTINGS.WEBHOOK_EVENTS.CARD_DELETED' },
  { value: 'task_overdue', labelKey: 'KANBAN_SETTINGS.WEBHOOK_EVENTS.TASK_OVERDUE' },
];

const createBlankWebhook = () => ({
  enabled: false,
  paused: false,
  url: '',
  secret: '',
  subscriptions: [],
  stage_ids: [],
  include_message_content: false,
  send_on_overdue: false,
});

const createBlankCondition = () => ({
  id: `condition-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  field: 'message.content',
  operator: 'contains',
  value: '',
});

const createBlankAction = () => ({
  id: `action-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  type: 'move_stage',
  value: '',
  stage_id: '',
  message_template: '',
  payload: {},
});

const createBlankAutomationRule = () => ({
  id: `rule-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  name: '',
  description: '',
  trigger: 'message_created',
  enabled: true,
  match_type: 'all',
  conditions: [createBlankCondition()],
  actions: [createBlankAction()],
});

const createBlankBoard = () => ({
  name: '',
  description: '',
  customAttributeKey: '',
  valueAttributeKey: 'deal_value',
  isDefault: false,
  webhook_url: '',
  webhook: createBlankWebhook(),
  automation_rules: [],
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
  webhook: {
    ...createBlankWebhook(),
    ...(board.webhook || {}),
    url: board.webhook?.url || board.webhook_url || '',
    subscriptions: board.webhook?.subscriptions || [],
    stage_ids: board.webhook?.stage_ids || [],
  },
  automation_rules: (board.automation_rules || []).map(rule => ({
    ...createBlankAutomationRule(),
    ...JSON.parse(JSON.stringify(rule)),
    conditions: (rule.conditions || []).length
      ? rule.conditions.map(condition => ({ ...createBlankCondition(), ...condition }))
      : [createBlankCondition()],
    actions: (rule.actions || []).length
      ? rule.actions.map(action => ({ ...createBlankAction(), ...action }))
      : [createBlankAction()],
  })),
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

const summaryItems = computed(() => [
  {
    label: t('KANBAN_SETTINGS.SUMMARY_STAGES'),
    value: localBoard.value.stages.length,
  },
  {
    label: t('KANBAN_SETTINGS.SUMMARY_RULES'),
    value: localBoard.value.automation_rules.length,
  },
  {
    label: t('KANBAN_SETTINGS.SUMMARY_AGENTS'),
    value: localBoard.value.agent_ids.length || t('KANBAN_SETTINGS.SUMMARY_ALL'),
  },
  {
    label: t('KANBAN_SETTINGS.SUMMARY_FIELDS'),
    value: localBoard.value.visible_attributes.length,
  },
]);

const boardHealthItems = computed(() => [
  {
    label: t('KANBAN_SETTINGS.SUMMARY_DEFAULT'),
    active: localBoard.value.isDefault,
  },
  {
    label: t('KANBAN_SETTINGS.SUMMARY_WEBHOOK'),
    active: !!localBoard.value.webhook.url && localBoard.value.webhook.enabled,
  },
  {
    label: t('KANBAN_SETTINGS.SUMMARY_AUTO_ASSIGN'),
    active: localBoard.value.auto_assign_inboxes.length > 0,
  },
  {
    label: t('KANBAN_SETTINGS.SUMMARY_VALUE'),
    active: enableValue.value,
  },
]);

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

const toggleWebhookSubscription = eventName => {
  const subscriptions = localBoard.value.webhook.subscriptions;
  localBoard.value.webhook.subscriptions = subscriptions.includes(eventName)
    ? subscriptions.filter(value => value !== eventName)
    : [...subscriptions, eventName];
};

const toggleWebhookStage = stageId => {
  const stageIds = localBoard.value.webhook.stage_ids;
  localBoard.value.webhook.stage_ids = stageIds.includes(stageId)
    ? stageIds.filter(value => value !== stageId)
    : [...stageIds, stageId];
};

const addAutomationRule = () => {
  localBoard.value.automation_rules.push(createBlankAutomationRule());
};

const removeAutomationRule = ruleIndex => {
  localBoard.value.automation_rules.splice(ruleIndex, 1);
};

const addRuleCondition = ruleIndex => {
  localBoard.value.automation_rules[ruleIndex].conditions.push(createBlankCondition());
};

const removeRuleCondition = (ruleIndex, conditionIndex) => {
  localBoard.value.automation_rules[ruleIndex].conditions.splice(conditionIndex, 1);
};

const addRuleAction = ruleIndex => {
  localBoard.value.automation_rules[ruleIndex].actions.push(createBlankAction());
};

const removeRuleAction = (ruleIndex, actionIndex) => {
  localBoard.value.automation_rules[ruleIndex].actions.splice(actionIndex, 1);
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
    webhook_url: localBoard.value.webhook.url,
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
                <div class="mb-4 flex items-center justify-between gap-3">
                  <div class="flex items-center gap-3">
                    <span class="inline-flex h-8 min-w-8 items-center justify-center rounded-full bg-n-surface-1 px-2 text-xs font-semibold text-n-slate-12">
                      {{ index + 1 }}
                    </span>
                    <div>
                      <p class="text-sm font-semibold text-n-slate-12">{{ stage.name || t('KANBAN_SETTINGS.NEW_STAGE') }}</p>
                      <p class="text-xs text-n-slate-10">{{ stage.id }}</p>
                    </div>
                  </div>
                  <span
                    class="inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium"
                    :style="{
                      backgroundColor: `${stage.color}18`,
                      color: stage.color,
                      borderColor: `${stage.color}33`,
                    }"
                  >
                    {{ t('KANBAN.COLUMN_ACTIONS.PREVIEW') }}
                  </span>
                </div>

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
                    <input v-model="stage.color" type="color" class="h-12 w-full rounded-2xl border border-n-weak bg-n-surface-1 px-2 py-2" />
                  </div>

                  <div class="space-y-2">
                    <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.WIP_LIMIT') }}</label>
                    <input v-model.number="stage.wipLimit" type="number" min="0" class="w-full rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.NO_LIMIT')" />
                  </div>

                  <button class="inline-flex h-11 w-11 items-center justify-center rounded-2xl text-n-ruby-11 transition-colors hover:bg-n-ruby-3/40" @click="removeStage(index)">
                    <i class="i-lucide-trash-2" />
                  </button>
                </div>

                <div class="mt-3 flex flex-wrap gap-2">
                  <button
                    v-for="preset in colorPresets"
                    :key="`${stage.id}-${preset.color}`"
                    type="button"
                    class="h-7 w-7 rounded-full border-2 transition-transform hover:scale-105"
                    :class="stage.color === preset.color ? 'border-n-slate-12' : 'border-white/80'"
                    :style="{ backgroundColor: preset.color }"
                    :title="preset.name"
                    @click="stage.color = preset.color"
                  />
                </div>
              </div>
            </div>
          </article>
        </section>

        <section class="space-y-6 xl:sticky xl:top-6 xl:self-start">
          <article class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-n-brand">
                  {{ t('KANBAN_SETTINGS.SUMMARY_TITLE') }}
                </p>
                <h2 class="mt-2 text-2xl font-semibold text-n-slate-12">
                  {{ localBoard.name || t('KANBAN_SETTINGS.NEW_BOARD') }}
                </h2>
                <p class="mt-2 text-sm text-n-slate-11">
                  {{ localBoard.description || t('KANBAN_SETTINGS.SUMMARY_DESCRIPTION') }}
                </p>
              </div>
              <span
                class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium"
                :class="canSave ? 'bg-n-teal-3 text-n-teal-11' : 'bg-n-amber-3 text-n-amber-11'"
              >
                {{ canSave ? t('KANBAN_SETTINGS.SUMMARY_READY') : t('KANBAN_SETTINGS.SUMMARY_PENDING') }}
              </span>
            </div>

            <div class="mt-5 grid gap-3 sm:grid-cols-2">
              <div
                v-for="item in summaryItems"
                :key="item.label"
                class="rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3"
              >
                <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ item.label }}</p>
                <p class="mt-2 text-xl font-semibold text-n-slate-12">{{ item.value }}</p>
              </div>
            </div>

            <div class="mt-5 flex flex-wrap gap-2">
              <span
                v-for="item in boardHealthItems"
                :key="item.label"
                class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium"
                :class="item.active ? 'bg-n-brand/10 text-n-blue-11' : 'bg-n-slate-2 text-n-slate-10'"
              >
                {{ item.label }}
              </span>
            </div>

            <div class="mt-5 rounded-2xl border border-n-weak bg-n-slate-1 p-4">
              <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
                {{ t('KANBAN_SETTINGS.SUMMARY_ATTRIBUTE_KEY') }}
              </p>
              <p class="mt-2 break-all text-sm font-medium text-n-slate-12">
                {{ localBoard.customAttributeKey || t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_PLACEHOLDER') }}
              </p>
            </div>

            <div class="mt-5 flex flex-wrap gap-3">
              <Button sm slate outline :label="t('KANBAN_SETTINGS.CANCEL')" @click="router.push({ name: isEditMode ? 'kanban_board' : 'kanban_funnels', params: isEditMode ? { boardId } : {} })" />
              <Button sm blue solid :label="t('KANBAN_SETTINGS.SAVE')" :disabled="!canSave" :is-loading="isSaving" @click="handleSave" />
            </div>
          </article>

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
                  <input v-model="localBoard.webhook.url" type="url" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.WEBHOOK_PLACEHOLDER')" />
                  <p class="text-xs text-n-slate-11">{{ t('KANBAN_SETTINGS.WEBHOOK_HELP') }}</p>
                </div>

                <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                  <input v-model="localBoard.webhook.enabled" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                  <span>{{ t('KANBAN_SETTINGS.WEBHOOK_ENABLED') }}</span>
                </label>

                <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                  <input v-model="localBoard.webhook.paused" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                  <span>{{ t('KANBAN_SETTINGS.WEBHOOK_PAUSED') }}</span>
                </label>

                <div class="space-y-2">
                  <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.WEBHOOK_SECRET') }}</label>
                  <input v-model="localBoard.webhook.secret" type="text" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.WEBHOOK_SECRET_PLACEHOLDER')" />
                </div>

                <div class="space-y-3">
                  <p class="text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.WEBHOOK_SUBSCRIPTIONS') }}</p>
                  <div class="grid gap-2 sm:grid-cols-2">
                    <label v-for="eventOption in webhookSubscriptionOptions" :key="eventOption.value" class="flex items-center gap-2 rounded-2xl border border-n-weak bg-n-slate-1 px-3 py-3 text-sm text-n-slate-12">
                      <input type="checkbox" :checked="localBoard.webhook.subscriptions.includes(eventOption.value)" class="rounded border-n-weak text-n-brand focus:ring-n-brand" @change="toggleWebhookSubscription(eventOption.value)" />
                      <span class="truncate">{{ t(eventOption.labelKey) }}</span>
                    </label>
                  </div>
                </div>

                <div class="space-y-3">
                  <p class="text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.WEBHOOK_STAGE_FILTER') }}</p>
                  <div class="grid gap-2 sm:grid-cols-2">
                    <label v-for="stage in localBoard.stages" :key="`webhook-${stage.id}`" class="flex items-center gap-2 rounded-2xl border border-n-weak bg-n-slate-1 px-3 py-3 text-sm text-n-slate-12">
                      <input type="checkbox" :checked="localBoard.webhook.stage_ids.includes(stage.id)" class="rounded border-n-weak text-n-brand focus:ring-n-brand" @change="toggleWebhookStage(stage.id)" />
                      <span class="truncate">{{ stage.name }}</span>
                    </label>
                  </div>
                </div>

                <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                  <input v-model="localBoard.webhook.include_message_content" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                  <span>{{ t('KANBAN_SETTINGS.WEBHOOK_INCLUDE_MESSAGE_CONTENT') }}</span>
                </label>

                <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                  <input v-model="localBoard.webhook.send_on_overdue" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                  <span>{{ t('KANBAN_SETTINGS.WEBHOOK_SEND_ON_OVERDUE') }}</span>
                </label>

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
            <p class="mt-1 text-sm text-n-slate-11">{{ t('KANBAN_SETTINGS.AGENTS_HELP') }}</p>
            <div class="mt-5 grid gap-2 sm:grid-cols-2">
              <label v-for="agent in agents" :key="agent.id" class="flex items-center gap-2 rounded-2xl border border-n-weak bg-n-slate-1 px-3 py-3 text-sm text-n-slate-12">
                <input type="checkbox" :checked="localBoard.agent_ids.includes(agent.id)" class="rounded border-n-weak text-n-brand focus:ring-n-brand" @change="toggleAgent(agent.id)" />
                <span class="truncate">{{ agent.name }}</span>
              </label>
            </div>
          </article>

          <article class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-xl font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.AUTOMATION_RULES') }}</h2>
                <p class="mt-1 text-sm text-n-slate-11">{{ t('KANBAN_SETTINGS.AUTOMATION_RULES_HELP') }}</p>
              </div>
              <Button sm blue solid icon="i-lucide-plus" :label="t('KANBAN_SETTINGS.ADD_RULE')" @click="addAutomationRule" />
            </div>

            <div v-if="localBoard.automation_rules.length" class="mt-6 space-y-4">
              <div v-for="(rule, ruleIndex) in localBoard.automation_rules" :key="rule.id" class="rounded-3xl border border-n-weak bg-n-slate-1 p-4">
                <div class="flex items-start justify-between gap-4">
                  <div class="grid flex-1 gap-4 md:grid-cols-2">
                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_NAME') }}</label>
                      <input v-model="rule.name" type="text" class="w-full rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.RULE_NAME_PLACEHOLDER')" />
                    </div>

                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_TRIGGER') }}</label>
                      <select v-model="rule.trigger" class="w-full rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                        <option v-for="trigger in automationTriggerOptions" :key="trigger.value" :value="trigger.value">{{ t(trigger.labelKey) }}</option>
                      </select>
                    </div>

                    <div class="space-y-2 md:col-span-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_DESCRIPTION') }}</label>
                      <textarea v-model="rule.description" rows="3" class="w-full rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.RULE_DESCRIPTION_PLACEHOLDER')" />
                    </div>
                  </div>

                  <button class="inline-flex h-11 w-11 items-center justify-center rounded-2xl text-n-ruby-11 transition-colors hover:bg-n-ruby-3/40" @click="removeAutomationRule(ruleIndex)">
                    <i class="i-lucide-trash-2" />
                  </button>
                </div>

                <div class="mt-4 flex flex-wrap gap-3">
                  <label class="flex items-center gap-3 rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm font-medium text-n-slate-12">
                    <input v-model="rule.enabled" type="checkbox" class="rounded border-n-weak text-n-brand focus:ring-n-brand" />
                    <span>{{ t('KANBAN_SETTINGS.RULE_ENABLED') }}</span>
                  </label>

                  <div class="space-y-2">
                    <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_MATCH_TYPE') }}</label>
                    <select v-model="rule.match_type" class="min-w-[180px] rounded-2xl border border-n-weak bg-n-surface-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                      <option value="all">{{ t('KANBAN_SETTINGS.RULE_MATCH_ALL') }}</option>
                      <option value="any">{{ t('KANBAN_SETTINGS.RULE_MATCH_ANY') }}</option>
                    </select>
                  </div>
                </div>

                <div class="mt-5 space-y-3">
                  <div class="flex items-center justify-between gap-3">
                    <h3 class="text-sm font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_CONDITIONS') }}</h3>
                    <Button sm slate outline icon="i-lucide-plus" :label="t('KANBAN_SETTINGS.ADD_CONDITION')" @click="addRuleCondition(ruleIndex)" />
                  </div>

                  <div v-for="(condition, conditionIndex) in rule.conditions" :key="condition.id" class="grid gap-3 rounded-2xl border border-n-weak bg-n-surface-1 p-3 lg:grid-cols-[minmax(0,1fr)_180px_minmax(0,1fr)_auto] lg:items-end">
                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_FIELD') }}</label>
                      <select v-model="condition.field" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                        <option v-for="fieldOption in automationFieldOptions" :key="fieldOption.value" :value="fieldOption.value">{{ t(fieldOption.labelKey) }}</option>
                      </select>
                    </div>

                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_OPERATOR') }}</label>
                      <select v-model="condition.operator" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                        <option v-for="operatorOption in automationOperatorOptions" :key="operatorOption.value" :value="operatorOption.value">{{ t(operatorOption.labelKey) }}</option>
                      </select>
                    </div>

                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_VALUE') }}</label>
                      <input v-model="condition.value" type="text" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.RULE_VALUE_PLACEHOLDER')" />
                    </div>

                    <button class="inline-flex h-11 w-11 items-center justify-center rounded-2xl text-n-ruby-11 transition-colors hover:bg-n-ruby-3/40" @click="removeRuleCondition(ruleIndex, conditionIndex)">
                      <i class="i-lucide-trash-2" />
                    </button>
                  </div>
                </div>

                <div class="mt-5 space-y-3">
                  <div class="flex items-center justify-between gap-3">
                    <h3 class="text-sm font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_ACTIONS_TITLE') }}</h3>
                    <Button sm slate outline icon="i-lucide-plus" :label="t('KANBAN_SETTINGS.ADD_ACTION')" @click="addRuleAction(ruleIndex)" />
                  </div>

                  <div v-for="(action, actionIndex) in rule.actions" :key="action.id" class="grid gap-3 rounded-2xl border border-n-weak bg-n-surface-1 p-3 lg:grid-cols-[180px_minmax(0,1fr)_180px_auto] lg:items-end">
                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_ACTION') }}</label>
                      <select v-model="action.type" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                        <option v-for="actionOption in automationActionOptions" :key="actionOption.value" :value="actionOption.value">{{ t(actionOption.labelKey) }}</option>
                      </select>
                    </div>

                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_ACTION_VALUE') }}</label>
                      <input v-model="action.value" type="text" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand" :placeholder="t('KANBAN_SETTINGS.RULE_ACTION_VALUE_PLACEHOLDER')" />
                    </div>

                    <div class="space-y-2">
                      <label class="block text-sm font-medium text-n-slate-12">{{ t('KANBAN_SETTINGS.RULE_ACTION_STAGE') }}</label>
                      <select v-model="action.stage_id" class="w-full rounded-2xl border border-n-weak bg-n-slate-1 px-4 py-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand">
                        <option value="">{{ t('KANBAN_SETTINGS.SELECT_STAGE') }}</option>
                        <option v-for="stage in localBoard.stages" :key="`${action.id}-${stage.id}`" :value="stage.id">{{ stage.name }}</option>
                      </select>
                    </div>

                    <button class="inline-flex h-11 w-11 items-center justify-center rounded-2xl text-n-ruby-11 transition-colors hover:bg-n-ruby-3/40" @click="removeRuleAction(ruleIndex, actionIndex)">
                      <i class="i-lucide-trash-2" />
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div v-else class="mt-6 rounded-3xl border border-dashed border-n-weak bg-n-slate-1 px-4 py-6 text-sm text-n-slate-11">
              {{ t('KANBAN_SETTINGS.NO_RULES') }}
            </div>
          </article>

          <article v-if="conversationAttributes.length > 0" class="rounded-[28px] border border-n-weak bg-n-surface-1 p-6">
            <h2 class="text-xl font-semibold text-n-slate-12">{{ t('KANBAN_SETTINGS.VISIBLE_ATTRIBUTES') }}</h2>
            <p class="mt-1 text-sm text-n-slate-11">{{ t('KANBAN_SETTINGS.VISIBLE_ATTRIBUTES_HELP') }}</p>
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