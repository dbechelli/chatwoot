<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
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
});

const showAdvanced = ref(false);
const enableValue = ref(!!props.board.valueAttributeKey);

// Auto-generate key for new boards
watch(() => localBoard.value.name, (newName) => {
  if (!props.board.id && !showAdvanced.value && newName) {
    const slug = newName.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    localBoard.value.customAttributeKey = slug ? `${slug}_status` : '';
  }
});

// Handle value tracking toggle
watch(enableValue, (enabled) => {
  if (!enabled) {
    localBoard.value.valueAttributeKey = '';
  } else if (!localBoard.value.valueAttributeKey) {
    localBoard.value.valueAttributeKey = 'deal_value';
  }
});

const agents = computed(() => store.getters['agents/getAgents']);
const conversationAttributes = computed(() => store.getters['attributes/getConversationAttributes']);

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('attributes/get');
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
</script>

<template>
  <Modal :show="true" :on-close="() => emit('close')">
    <div class="flex flex-col h-full max-h-[90vh] w-full max-w-4xl">
      <!-- Header -->
      <div class="flex items-center justify-between p-6 border-b border-n-weak">
        <div>
          <h2 class="text-2xl font-bold text-n-slate-12">
            {{
              board.id
                ? $t('KANBAN_SETTINGS.EDIT_BOARD')
                : $t('KANBAN_SETTINGS.CREATE_BOARD')
            }}
          </h2>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ $t('KANBAN_SETTINGS.BOARD_EDITOR_DESCRIPTION') }}
          </p>
        </div>
      </div>

      <!-- Content -->
      <div class="flex-1 overflow-y-auto p-6 space-y-6">
        <!-- Configurações básicas -->
        <div class="space-y-4">
          <h3 class="text-lg font-semibold text-n-slate-12">
            {{ $t('KANBAN_SETTINGS.BASIC_CONFIG') }}
          </h3>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.BOARD_NAME') }}
                <span class="text-red-500">*</span>
              </label>
              <input
                v-model="localBoard.name"
                type="text"
                class="w-full px-3 py-2 border border-n-weak rounded-lg focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 outline-none"
                :placeholder="$t('KANBAN_SETTINGS.BOARD_NAME_PLACEHOLDER')"
              />
            </div>

            <div v-if="showAdvanced">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_KEY') }}
                <span class="text-red-500">*</span>
              </label>
              <input
                v-model="localBoard.customAttributeKey"
                type="text"
                class="w-full px-3 py-2 border border-n-weak rounded-lg focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 outline-none"
                placeholder="sales_stage"
              />
              <p class="text-xs text-n-slate-11 mt-1">
                {{ $t('KANBAN_SETTINGS.CUSTOM_ATTRIBUTE_HELP') }}
              </p>
            </div>

            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.AGENTS') }}
              </label>
              <div class="grid grid-cols-2 md:grid-cols-3 gap-2 max-h-40 overflow-y-auto border border-n-weak rounded-lg p-2">
                <label
                  v-for="agent in agents"
                  :key="agent.id"
                  class="flex items-center gap-2 p-2 rounded hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    type="checkbox"
                    :checked="localBoard.agent_ids.includes(agent.id)"
                    @change="toggleAgent(agent.id)"
                    class="rounded border-n-weak text-n-brand focus:ring-n-brand"
                  />
                  <span class="text-sm text-n-slate-12">{{ agent.name }}</span>
                </label>
              </div>
              <p class="text-xs text-n-slate-11 mt-1">
                {{ $t('KANBAN_SETTINGS.AGENTS_HELP') }}
              </p>
            </div>

            <div class="md:col-span-2" v-if="conversationAttributes.length > 0">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.VISIBLE_ATTRIBUTES') }}
              </label>
              <div class="grid grid-cols-2 md:grid-cols-3 gap-2 max-h-40 overflow-y-auto border border-n-weak rounded-lg p-2">
                <label
                  v-for="attr in conversationAttributes"
                  :key="attr.attributeKey"
                  class="flex items-center gap-2 p-2 rounded hover:bg-n-alpha-1 cursor-pointer"
                >
                  <input
                    type="checkbox"
                    :checked="localBoard.visible_attributes.includes(attr.attributeKey)"
                    @change="toggleAttribute(attr.attributeKey)"
                    class="rounded border-n-weak text-n-brand focus:ring-n-brand"
                  />
                  <span class="text-sm text-n-slate-12">{{ attr.attributeDisplayName }}</span>
                </label>
              </div>
              <p class="text-xs text-n-slate-11 mt-1">
                {{ $t('KANBAN_SETTINGS.VISIBLE_ATTRIBUTES_HELP') }}
              </p>
            </div>

            <div class="md:col-span-2">
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                {{ $t('KANBAN_SETTINGS.DESCRIPTION') }}
              </label>
              <textarea
                v-model="localBoard.description"
                rows="2"
                class="w-full px-3 py-2 border border-n-weak rounded-lg focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 outline-none resize-none"
                :placeholder="$t('KANBAN_SETTINGS.DESCRIPTION_PLACEHOLDER')"
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

              <div v-if="showAdvanced && enableValue">
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ $t('KANBAN_SETTINGS.VALUE_ATTRIBUTE_KEY') }}
                </label>
                <input
                  v-model="localBoard.valueAttributeKey"
                  type="text"
                  class="w-full px-3 py-2 border border-n-weak rounded-lg focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 outline-none"
                  placeholder="deal_value"
                />
                <p class="text-xs text-n-slate-11 mt-1">
                  {{ $t('KANBAN_SETTINGS.VALUE_ATTRIBUTE_HELP') }}
                </p>
              </div>
            </div>

            <div class="md:col-span-2 pt-2">
              <button
                type="button"
                class="text-sm text-n-brand hover:underline flex items-center gap-1"
                @click="showAdvanced = !showAdvanced"
              >
                <i :class="showAdvanced ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'" />
                {{ $t('KANBAN_SETTINGS.ADVANCED_CONFIG') }}
              </button>
            </div>

            <!-- Webhook Section -->
            <div class="md:col-span-2 pt-4 border-t border-n-weak mt-2">
              <h4 class="text-sm font-bold text-n-slate-12 mb-3 flex items-center gap-2">
                <i class="i-lucide-webhook text-n-brand" />
                Automação (Webhook)
              </h4>
              <div class="space-y-2">
                <label class="block text-sm font-medium text-n-slate-12">
                  URL do Webhook
                </label>
                <input
                  v-model="localBoard.webhook_url"
                  type="url"
                  class="w-full px-3 py-2 border border-n-weak rounded-lg focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 outline-none"
                  placeholder="https://n8n.seu-dominio.com/webhook/..."
                />
                <p class="text-xs text-n-slate-11">
                  Quando um card for movido, enviaremos um POST para esta URL com os dados do item.
                </p>
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

        <!-- Estágios -->
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold text-n-slate-12">
              {{ $t('KANBAN_SETTINGS.STAGES') }}
              <span class="text-red-500">*</span>
            </h3>
            <button
              class="inline-flex items-center gap-2 px-3 py-1.5 bg-n-brand text-white rounded-lg text-sm hover:bg-n-brand/90 transition-colors"
              @click="addStage"
            >
              <i class="i-lucide-plus" />
              {{ $t('KANBAN_SETTINGS.ADD_STAGE') }}
            </button>
          </div>

          <div class="space-y-3">
            <div
              v-for="(stage, index) in localBoard.stages"
              :key="stage.id"
              class="flex items-start gap-3 p-4 border border-n-weak rounded-lg bg-white hover:border-n-brand/50 transition-colors"
            >
              <!-- Order controls -->
              <div class="flex flex-col gap-1">
                <button
                  class="p-1 text-n-slate-11 hover:text-n-brand hover:bg-n-slate-2 rounded disabled:opacity-30"
                  :disabled="index === 0"
                  @click="moveStageUp(index)"
                >
                  <i class="i-lucide-chevron-up" />
                </button>
                <button
                  class="p-1 text-n-slate-11 hover:text-n-brand hover:bg-n-slate-2 rounded disabled:opacity-30"
                  :disabled="index === localBoard.stages.length - 1"
                  @click="moveStageDown(index)"
                >
                  <i class="i-lucide-chevron-down" />
                </button>
              </div>

              <!-- Stage content -->
              <div class="flex-1 grid grid-cols-1 md:grid-cols-3 gap-3">
                <!-- Nome -->
                <div>
                  <label class="block text-xs font-medium text-n-slate-11 mb-1">
                    {{ $t('KANBAN_SETTINGS.STAGE_NAME') }}
                  </label>
                  <input
                    v-model="stage.name"
                    type="text"
                    class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg focus:border-n-brand focus:ring-1 focus:ring-n-brand/20 outline-none"
                    :placeholder="$t('KANBAN_SETTINGS.STAGE_NAME_PLACEHOLDER')"
                  />
                </div>

                <!-- Cor -->
                <div>
                  <label class="block text-xs font-medium text-n-slate-11 mb-1">
                    {{ $t('KANBAN_SETTINGS.COLOR') }}
                  </label>
                  <div class="flex items-center gap-2">
                    <select
                      v-model="stage.color"
                      class="flex-1 px-3 py-2 text-sm border border-n-weak rounded-lg focus:border-n-brand focus:ring-1 focus:ring-n-brand/20 outline-none"
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
                      class="w-8 h-8 rounded border-2 border-white shadow-sm flex-shrink-0"
                      :style="{ backgroundColor: stage.color }"
                    />
                  </div>
                </div>

                <!-- WIP Limit -->
                <div>
                  <label class="block text-xs font-medium text-n-slate-11 mb-1">
                    {{ $t('KANBAN_SETTINGS.WIP_LIMIT') }}
                  </label>
                  <input
                    v-model.number="stage.wipLimit"
                    type="number"
                    min="0"
                    class="w-full px-3 py-2 text-sm border border-n-weak rounded-lg focus:border-n-brand focus:ring-1 focus:ring-n-brand/20 outline-none"
                    :placeholder="$t('KANBAN_SETTINGS.NO_LIMIT')"
                  />
                </div>
              </div>

              <!-- Delete button -->
              <button
                class="p-2 text-red-600 hover:bg-red-50 rounded transition-colors"
                @click="removeStage(index)"
              >
                <i class="i-lucide-trash-2" />
              </button>
            </div>

            <!-- Empty state -->
            <div
              v-if="!localBoard.stages || localBoard.stages.length === 0"
              class="flex flex-col items-center justify-center p-8 border-2 border-dashed border-n-weak rounded-lg bg-n-slate-1"
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
        class="flex items-center justify-end gap-3 p-6 border-t border-n-weak"
      >
        <button
          class="px-4 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-slate-3 rounded-lg transition-colors"
          @click="$emit('close')"
        >
          {{ $t('KANBAN_SETTINGS.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm font-medium bg-n-brand text-white rounded-lg hover:bg-n-brand/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          :disabled="!canSave"
          @click="handleSave"
        >
          {{ $t('KANBAN_SETTINGS.SAVE') }}
        </button>
      </div>
    </div>
  </Modal>
</template>
