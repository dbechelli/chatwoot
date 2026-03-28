<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import Button from 'dashboard/components-next/button/Button.vue';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  board: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['save', 'close']);

const { t } = useI18n();
const store = useStore();

const localBoard = ref({
  ...props.board,
  agent_ids: props.board.agent_ids || [],
  visible_attributes: props.board.visible_attributes || [],
  auto_assign_inboxes: props.board.auto_assign_inboxes || [],
  auto_assign_stage_id: props.board.auto_assign_stage_id || '',
  enable_round_robin: props.board.enable_round_robin || false,
});

const showAdvanced = ref(false);
const enableValue = ref(!!props.board.valueAttributeKey);

// Auto-generate key for new boards
watch(
  () => localBoard.value.name,
  newName => {
    if (!props.board.id && !showAdvanced.value && newName) {
      const slug = newName
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/^_+|_+$/g, '');
      localBoard.value.customAttributeKey = slug ? `${slug}_status` : '';
    }
  }
);

// Handle value tracking toggle
watch(enableValue, enabled => {
  if (!enabled) {
    localBoard.value.valueAttributeKey = '';
  } else if (!localBoard.value.valueAttributeKey) {
    localBoard.value.valueAttributeKey = 'deal_value';
  }
});

const agents = computed(() => store.getters['agents/getAgents']);
const inboxes = computed(() => store.getters['inboxes/getInboxes']);
const conversationAttributes = computed(
  () => store.getters['attributes/getConversationAttributes']
);

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('attributes/get');
  store.dispatch('inboxes/get');
});

const toggleAgent = agentId => {
  const index = localBoard.value.agent_ids.indexOf(agentId);
  if (index === -1) {
    localBoard.value.agent_ids.push(agentId);
  } else {
    localBoard.value.agent_ids.splice(index, 1);
  }
};

const toggleAttribute = key => {
  const index = localBoard.value.visible_attributes.indexOf(key);
  if (index === -1) {
    localBoard.value.visible_attributes.push(key);
  } else {
    localBoard.value.visible_attributes.splice(index, 1);
  }
};

const colorPresets = [
  { color: '#3b82f6', name: 'Blue' },
  { color: '#8b5cf6', name: 'Purple' },
  { color: '#f59e0b', name: 'Orange' },
  { color: '#ec4899', name: 'Pink' },
  { color: '#10b981', name: 'Green' },
  { color: '#ef4444', name: 'Red' },
  { color: '#6366f1', name: 'Indigo' },
  { color: '#64748b', name: 'Slate' },
];

const addStage = () => {
  if (!localBoard.value.stages) {
    localBoard.value.stages = [];
  }

  localBoard.value.stages.push({
    id: `stage-${Date.now()}`,
    name: t('KANBAN_SETTINGS.NEW_STAGE'),
    color: '#3b82f6',
    order: localBoard.value.stages.length + 1,
    wipLimit: null,
  });
};

const removeStage = index => {
  localBoard.value.stages.splice(index, 1);
  // Reordenar
  localBoard.value.stages.forEach((stage, i) => {
    stage.order = i + 1;
  });
};

const moveStageUp = index => {
  if (index === 0) return;
  const temp = localBoard.value.stages[index];
  localBoard.value.stages[index] = localBoard.value.stages[index - 1];
  localBoard.value.stages[index - 1] = temp;
  // Atualizar order
  localBoard.value.stages.forEach((stage, i) => {
    stage.order = i + 1;
  });
};

const moveStageDown = index => {
  if (index === localBoard.value.stages.length - 1) return;
  const temp = localBoard.value.stages[index];
  localBoard.value.stages[index] = localBoard.value.stages[index + 1];
  localBoard.value.stages[index + 1] = temp;
  // Atualizar order
  localBoard.value.stages.forEach((stage, i) => {
    stage.order = i + 1;
  });
};

const handleSave = () => {
  emit('save', localBoard.value);
};

const canSave = computed(() => {
  return (
    localBoard.value.name &&
    localBoard.value.customAttributeKey &&
    localBoard.value.stages &&
    localBoard.value.stages.length > 0
  );
});

const fieldClass =
  'w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand focus:ring-2 focus:ring-n-brand/20';

const sectionCardClass =
  'rounded-2xl border border-n-weak bg-n-surface-1 p-4 md:p-5';
</script>

<template>
  <Modal show :on-close="() => emit('close')">
    <div class="flex flex-col h-full max-h-[90vh] w-full max-w-4xl">
      <!-- Header -->
      <div
        class="flex items-center justify-between p-4 md:p-6 border-b border-n-weak"
      >
        <div class="flex-1 min-w-0">
          <h2 class="text-lg md:text-2xl font-bold text-n-slate-12 truncate">
            {{
              board.id
                ? $t('KANBAN_SETTINGS.EDIT_BOARD')
                : $t('KANBAN_SETTINGS.CREATE_BOARD')
            }}
          </h2>
          <p class="text-xs md:text-sm text-n-slate-11 mt-1">
            {{ $t('KANBAN_SETTINGS.BOARD_EDITOR_DESCRIPTION') }}
          </p>
        </div>
        <button
          class="ml-3 p-2 hover:bg-n-slate-2 rounded-lg transition-colors flex-shrink-0"
          @click="$emit('close')"
        >
          <i class="i-lucide-x text-xl text-n-slate-11" />
        </button>
      </div>

      <!-- Content -->
      <div class="flex-1 space-y-4 overflow-y-auto p-4 md:space-y-6 md:p-6">
        <div class="space-y-3 md:space-y-4">
          <h3 class="text-base md:text-lg font-semibold text-n-slate-12">
            {{ $t('KANBAN_SETTINGS.BASIC_CONFIG') }}
          </h3>

          <div :class="sectionCardClass" class="grid grid-cols-1 gap-3 md:grid-cols-2 md:gap-4">
            <div class="space-y-2">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.BOARD_NAME') }}
                <span class="text-red-500">{{
                  $t('KANBAN_SETTINGS.REQUIRED')
                }}</span>
              </label>
              <input
                v-model="localBoard.name"
                type="text"
                :class="fieldClass"
                :placeholder="$t('KANBAN_SETTINGS.BOARD_NAME_PLACEHOLDER')"
              />
            </div>

            <div v-if="showAdvanced" class="space-y-2">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_KEY') }}
                <span class="text-red-500">{{
                  $t('KANBAN_SETTINGS.REQUIRED')
                }}</span>
              </label>
              <input
                v-model="localBoard.customAttributeKey"
                type="text"
                :class="fieldClass"
                :placeholder="
                  $t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_PLACEHOLDER')
                "
              />
              <p class="text-xs text-n-slate-11 mt-1">
                {{ $t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_HELP') }}
              </p>
            </div>

            <div class="md:col-span-2">
              <label
                class="block text-xs md:text-sm font-medium text-n-slate-12 mb-2"
              >
                {{ $t('KANBAN_SETTINGS.AGENTS') }}
              </label>
              <div
                class="grid max-h-32 grid-cols-1 gap-2 overflow-y-auto rounded-2xl border border-n-weak bg-n-slate-1 p-2 sm:grid-cols-2 md:max-h-40 md:grid-cols-3"
              >
                <label
                  v-for="agent in agents"
                  :key="agent.id"
                  class="flex cursor-pointer items-center gap-2 rounded-xl bg-n-surface-1 p-2 hover:bg-n-alpha-1"
                >
                  <input
                    type="checkbox"
                    :checked="localBoard.agent_ids.includes(agent.id)"
                    class="rounded border-n-weak text-n-brand focus:ring-n-brand flex-shrink-0"
                    @change="toggleAgent(agent.id)"
                  />
                  <span class="text-xs md:text-sm text-n-slate-12 truncate">{{
                    agent.name
                  }}</span>
                </label>
              </div>
              <p class="text-xs text-n-slate-11 mt-1">
                {{ $t('KANBAN_SETTINGS.AGENTS_HELP') }}
              </p>
            </div>

            <div v-if="conversationAttributes.length > 0" class="md:col-span-2">
              <label
                class="block text-xs md:text-sm font-medium text-n-slate-12 mb-2"
              >
                {{ $t('KANBAN_SETTINGS.VISIBLE_ATTRIBUTES') }}
              </label>
              <div
                class="grid max-h-32 grid-cols-1 gap-2 overflow-y-auto rounded-2xl border border-n-weak bg-n-slate-1 p-2 sm:grid-cols-2 md:max-h-40 md:grid-cols-3"
              >
                <label
                  v-for="attr in conversationAttributes"
                  :key="attr.attributeKey"
                  class="flex cursor-pointer items-center gap-2 rounded-xl bg-n-surface-1 p-2 hover:bg-n-alpha-1"
                >
                  <input
                    type="checkbox"
                    :checked="
                      localBoard.visible_attributes.includes(attr.attributeKey)
                    "
                    class="rounded border-n-weak text-n-brand focus:ring-n-brand flex-shrink-0"
                    @change="toggleAttribute(attr.attributeKey)"
                  />
                  <span class="text-xs md:text-sm text-n-slate-12 truncate">{{
                    attr.attributeDisplayName
                  }}</span>
                </label>
              </div>
              <p class="text-xs text-n-slate-11 mt-1">
                {{ $t('KANBAN_SETTINGS.VISIBLE_ATTRIBUTES_HELP') }}
              </p>
            </div>

            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.BOARD_DESCRIPTION') }}
              </label>
              <textarea
                v-model="localBoard.description"
                rows="2"
                :class="`${fieldClass} resize-none`"
                :placeholder="
                  $t('KANBAN_SETTINGS.BOARD_DESCRIPTION_PLACEHOLDER')
                "
              />
            </div>

            <div class="md:col-span-2 space-y-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  v-model="enableValue"
                  type="checkbox"
                  class="w-4 h-4 rounded border-n-slate-6 text-n-brand focus:ring-n-brand"
                />
                <span class="text-sm font-medium text-n-slate-12">
                  {{ $t('KANBAN_SETTINGS.ENABLE_VALUE') }}
                </span>
              </label>
              <p class="text-xs text-n-slate-11 ml-6 -mt-3">
                {{ $t('KANBAN_SETTINGS.ENABLE_VALUE_HELP') }}
              </p>

              <div v-if="showAdvanced && enableValue" class="space-y-2 rounded-2xl border border-n-weak bg-n-slate-1 p-3">
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ $t('KANBAN_SETTINGS.VALUE_ATTRIBUTE_KEY') }}
                </label>
                <input
                  v-model="localBoard.valueAttributeKey"
                  type="text"
                  :class="fieldClass"
                  :placeholder="
                    $t('KANBAN_SETTINGS.VALUE_ATTRIBUTE_PLACEHOLDER')
                  "
                />
                <p class="text-xs text-n-slate-11 mt-1">
                  {{ $t('KANBAN_SETTINGS.VALUE_ATTRIBUTE_HELP') }}
                </p>
              </div>
            </div>

            <div class="md:col-span-2 pt-2">
              <button
                type="button"
                class="inline-flex items-center gap-1 text-sm font-medium text-n-brand hover:underline"
                @click="showAdvanced = !showAdvanced"
              >
                <i
                  :class="
                    showAdvanced
                      ? 'i-lucide-chevron-up'
                      : 'i-lucide-chevron-down'
                  "
                />
                {{ $t('KANBAN_SETTINGS.ADVANCED_CONFIG') }}
              </button>
            </div>

            <!-- Webhook Section -->
            <div class="md:col-span-2 mt-2 border-t border-n-weak pt-3 md:pt-4">
              <h4
                class="text-xs md:text-sm font-bold text-n-slate-12 mb-3 flex items-center gap-2"
              >
                <i class="i-lucide-webhook text-n-brand" />
                {{ $t('KANBAN_SETTINGS.WEBHOOK_AUTOMATION') }}
              </h4>
              <div class="space-y-2">
                <label
                  class="block text-xs md:text-sm font-medium text-n-slate-12"
                >
                  {{ $t('KANBAN_SETTINGS.WEBHOOK_URL') }}
                </label>
                <input
                  v-model="localBoard.webhook_url"
                  type="url"
                  :class="fieldClass"
                  :placeholder="$t('KANBAN_SETTINGS.WEBHOOK_PLACEHOLDER')"
                />
                <p class="text-xs text-n-slate-11">
                  {{ $t('KANBAN_SETTINGS.WEBHOOK_HELP') }}
                </p>
              </div>
            </div>

            <!-- Auto Assign -->
            <div class="md:col-span-2 mt-2 border-t border-n-weak pt-3 md:pt-4">
              <h4
                class="text-xs md:text-sm font-bold text-n-slate-12 mb-3 flex items-center gap-2"
              >
                <i class="i-lucide-zap text-amber-500" />
                {{ $t('KANBAN_SETTINGS.AUTO_ASSIGN') }}
              </h4>
              <p class="text-xs text-n-slate-11 mb-3">
                {{ $t('KANBAN_SETTINGS.AUTO_ASSIGN_DESCRIPTION') }}
              </p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 md:gap-4">
                <div>
                  <label
                    class="block text-xs md:text-sm font-medium text-n-slate-12 mb-2"
                  >
                    {{ $t('KANBAN_SETTINGS.INBOXES') }}
                  </label>
                  <div
                    class="grid max-h-32 grid-cols-1 gap-2 overflow-y-auto rounded-2xl border border-n-weak bg-n-slate-1 p-2 md:max-h-40"
                  >
                    <label
                      v-for="inbox in inboxes"
                      :key="inbox.id"
                      class="flex cursor-pointer items-center gap-2 rounded-xl bg-n-surface-1 p-2 hover:bg-n-alpha-1"
                    >
                      <input
                        v-model="localBoard.auto_assign_inboxes"
                        type="checkbox"
                        :value="inbox.id"
                        class="rounded border-n-weak text-n-brand focus:ring-n-brand flex-shrink-0"
                      />
                      <span
                        class="text-xs md:text-sm text-n-slate-12 truncate"
                        >{{ inbox.name }}</span
                      >
                    </label>
                  </div>
                </div>

                <div>
                  <label
                    class="block text-xs md:text-sm font-medium text-n-slate-12 mb-2"
                  >
                    {{ $t('KANBAN_SETTINGS.INITIAL_STAGE') }}
                  </label>
                  <select
                    v-model="localBoard.auto_assign_stage_id"
                    :class="fieldClass"
                  >
                    <option value="">
                      {{ $t('KANBAN_SETTINGS.SELECT_STAGE') }}
                    </option>
                    <option
                      v-for="stage in localBoard.stages"
                      :key="stage.id"
                      :value="stage.id"
                    >
                      {{ stage.name }}
                    </option>
                  </select>

                  <div class="mt-3 md:mt-4">
                    <label
                      class="flex cursor-pointer items-start gap-3 rounded-2xl border border-n-weak bg-n-slate-1 p-3 hover:bg-n-brand/5"
                    >
                      <div
                        class="mt-0.5 flex h-5 w-5 flex-shrink-0 items-center justify-center rounded border border-n-weak bg-n-surface-1"
                        :class="{
                          'bg-n-brand border-n-brand':
                            localBoard.enable_round_robin,
                        }"
                      >
                        <input
                          v-model="localBoard.enable_round_robin"
                          type="checkbox"
                          class="opacity-0 absolute"
                        />
                        <i
                          v-if="localBoard.enable_round_robin"
                          class="i-lucide-check text-white text-xs"
                        />
                      </div>
                      <div class="flex-1 min-w-0">
                        <span
                          class="text-xs md:text-sm font-medium text-n-slate-12 block"
                          >{{ $t('KANBAN_SETTINGS.ROUND_ROBIN') }}</span
                        >
                        <span class="text-xs text-n-slate-11 block mt-0.5">{{
                          $t('KANBAN_SETTINGS.ROUND_ROBIN_HELP')
                        }}</span>
                      </div>
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div class="pt-7">
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  v-model="localBoard.isDefault"
                  type="checkbox"
                  class="w-4 h-4 rounded border-n-slate-6 text-n-brand focus:ring-n-brand"
                />
                <span class="text-sm font-medium text-n-slate-12">
                  {{ $t('KANBAN_SETTINGS.SET_AS_DEFAULT') }}
                </span>
              </label>
            </div>
          </div>
        </div>

        <div class="space-y-3 md:space-y-4">
          <div
            class="flex flex-col sm:flex-row sm:items-center justify-between gap-3"
          >
            <h3 class="text-base md:text-lg font-semibold text-n-slate-12">
              {{ $t('KANBAN_SETTINGS.STAGES') }}
              <span class="text-red-500">{{
                $t('KANBAN_SETTINGS.REQUIRED')
              }}</span>
            </h3>
            <Button
              sm
              icon="i-lucide-plus"
              :label="$t('KANBAN_SETTINGS.ADD_STAGE')"
              @click="addStage"
            />
          </div>

          <div class="space-y-3">
            <div
              v-for="(stage, index) in localBoard.stages"
              :key="stage.id"
              class="flex items-start gap-2 rounded-2xl border border-n-weak bg-n-surface-1 p-3 transition-colors hover:border-n-brand/50 md:gap-3 md:p-4"
            >
              <div class="flex flex-col gap-1 flex-shrink-0">
                <button
                  class="p-1 text-n-slate-11 hover:text-n-brand hover:bg-n-slate-2 rounded disabled:opacity-30"
                  :disabled="index === 0"
                  @click="moveStageUp(index)"
                >
                  <i class="i-lucide-chevron-up text-sm" />
                </button>
                <button
                  class="p-1 text-n-slate-11 hover:text-n-brand hover:bg-n-slate-2 rounded disabled:opacity-30"
                  :disabled="index === localBoard.stages.length - 1"
                  @click="moveStageDown(index)"
                >
                  <i class="i-lucide-chevron-down text-sm" />
                </button>
              </div>

              <div
                class="flex-1 grid grid-cols-1 md:grid-cols-3 gap-2 md:gap-3"
              >
                <div>
                  <label class="block text-xs font-medium text-n-slate-11 mb-1">
                    {{ $t('KANBAN_SETTINGS.STAGE_NAME') }}
                  </label>
                  <input
                    v-model="stage.name"
                    type="text"
                    :class="fieldClass"
                    :placeholder="$t('KANBAN_SETTINGS.STAGE_NAME_PLACEHOLDER')"
                  />
                </div>

                <div>
                  <label class="block text-xs font-medium text-n-slate-11 mb-1">
                    {{ $t('KANBAN_SETTINGS.COLOR') }}
                  </label>
                  <div class="flex items-center gap-2">
                    <select
                      v-model="stage.color"
                      :class="fieldClass"
                    >
                      <option
                        v-for="preset in colorPresets"
                        :key="preset.color"
                        :value="preset.color"
                      >
                        {{ preset.name }}
                      </option>
                    </select>
                    <div
                      class="h-8 w-8 flex-shrink-0 rounded-xl border border-n-weak"
                      :style="{ backgroundColor: stage.color }"
                    />
                  </div>
                </div>

                <div>
                  <label class="block text-xs font-medium text-n-slate-11 mb-1">
                    {{ $t('KANBAN_SETTINGS.WIP_LIMIT') }}
                  </label>
                  <input
                    v-model.number="stage.wipLimit"
                    type="number"
                    min="0"
                    :class="fieldClass"
                    :placeholder="$t('KANBAN_SETTINGS.NO_LIMIT')"
                  />
                </div>
              </div>

              <button
                class="rounded-xl p-2 text-n-ruby-11 transition-colors hover:bg-n-ruby-9/10"
                @click="removeStage(index)"
              >
                <i class="i-lucide-trash-2" />
              </button>
            </div>

            <div
              v-if="!localBoard.stages || localBoard.stages.length === 0"
              class="flex flex-col items-center justify-center rounded-2xl border-2 border-dashed border-n-weak bg-n-slate-1 p-8"
            >
              <i class="i-lucide-list text-4xl text-n-slate-6 mb-2" />
              <p class="text-sm text-n-slate-11">
                {{ $t('KANBAN_SETTINGS.NO_STAGES') }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div
        class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center justify-end gap-2 md:gap-3 p-4 md:p-6 border-t border-n-weak"
      >
        <Button
          sm
          ghost
          slate
          :label="$t('KANBAN_SETTINGS.CANCEL')"
          @click="$emit('close')"
        />
        <Button
          sm
          :label="$t('KANBAN_SETTINGS.SAVE')"
          :disabled="!canSave"
          @click="handleSave"
        />
      </div>
    </div>
  </Modal>
</template>
