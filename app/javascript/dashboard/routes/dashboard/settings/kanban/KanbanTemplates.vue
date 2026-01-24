<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';

defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'selectTemplate']);
const { t } = useI18n();

const templateDefinitions = ref([
  {
    id: 'sales_pipeline',
    key: 'SALES_PIPELINE',
    icon: 'i-lucide-trending-up',
    iconBg: '#d1fae5',
    iconColor: '#10b981',
    stageColors: ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#ec4899', '#10b981', '#ef4444'],
  },
  {
    id: 'customer_support',
    key: 'CUSTOMER_SUPPORT',
    icon: 'i-lucide-headphones',
    iconBg: '#dbeafe',
    iconColor: '#3b82f6',
    stageColors: ['#3b82f6', '#8b5cf6', '#f59e0b', '#10b981', '#64748b'],
  },
  {
    id: 'recruitment',
    key: 'RECRUITMENT',
    icon: 'i-lucide-user-plus',
    iconBg: '#e9d5ff',
    iconColor: '#8b5cf6',
    stageColors: ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#ec4899', '#10b981', '#ef4444'],
  },
  {
    id: 'onboarding',
    key: 'ONBOARDING',
    icon: 'i-lucide-rocket',
    iconBg: '#fed7aa',
    iconColor: '#f59e0b',
    stageColors: ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#10b981'],
  },
  {
    id: 'project_management',
    key: 'PROJECT_MANAGEMENT',
    icon: 'i-lucide-folder-kanban',
    iconBg: '#e0e7ff',
    iconColor: '#6366f1',
    stageColors: ['#64748b', '#3b82f6', '#f59e0b', '#8b5cf6', '#10b981'],
  },
  {
    id: 'lead_qualification',
    key: 'LEAD_QUALIFICATION',
    icon: 'i-lucide-filter',
    iconBg: '#cffafe',
    iconColor: '#06b6d4',
    stageColors: ['#3b82f6', '#8b5cf6', '#10b981', '#ef4444', '#06b6d4'],
  },
]);

const templates = computed(() => {
  return templateDefinitions.value.map(tmpl => {
    const baseKey = `KANBAN_SETTINGS.TEMPLATES.${tmpl.key}`;
    const stagesKey = `${baseKey}.STAGES`;

    // Get all stage keys for this template
    const stageKeys = Object.keys(t(stagesKey));

    const stages = stageKeys.map((key, index) => ({
      id: key.toLowerCase(),
      name: t(`${stagesKey}.${key}`),
      color: tmpl.stageColors[index] || '#64748b',
      order: index + 1,
    }));

    return {
      id: tmpl.id,
      name: t(`${baseKey}.NAME`),
      description: t(`${baseKey}.DESCRIPTION`),
      icon: tmpl.icon,
      iconBg: tmpl.iconBg,
      iconColor: tmpl.iconColor,
      stages,
    };
  });
});

const selectTemplate = template => {
  const boardData = {
    name: template.name,
    description: template.description,
    customAttributeKey: `${template.id}_status`,
    valueAttributeKey: 'deal_value',
    isDefault: false,
    stages: template.stages,
  };

  emit('selectTemplate', boardData);
  emit('close');
};
</script>

<template>
  <Modal :show="show" :on-close="() => emit('close')">
    <div class="flex flex-col h-full max-h-[90vh] w-full max-w-5xl">
      <!-- Header -->
      <div
        class="flex items-center justify-between p-4 md:p-6 border-b border-n-weak"
      >
        <div>
          <h2 class="text-xl md:text-2xl font-bold text-n-slate-12">
            {{ $t('KANBAN_SETTINGS.TEMPLATES_TITLE') }}
          </h2>
          <p class="text-xs md:text-sm text-n-slate-11 mt-1">
            {{ $t('KANBAN_SETTINGS.TEMPLATES_DESCRIPTION') }}
          </p>
        </div>
        <button
          class="p-2 hover:bg-n-slate-2 rounded-lg transition-colors"
          @click="$emit('close')"
        >
          <i class="i-lucide-x text-xl text-n-slate-11" />
        </button>
      </div>

      <!-- Content -->
      <div class="flex-1 overflow-y-auto p-4 md:p-6">
        <div
          class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4"
        >
          <div
            v-for="template in templates"
            :key="template.id"
            class="group border border-n-weak rounded-lg p-4 md:p-5 hover:shadow-md hover:border-n-brand transition-all cursor-pointer bg-white"
            @click="selectTemplate(template)"
          >
            <!-- Icon & Title -->
            <div class="flex items-start gap-3 md:gap-4 mb-3 md:mb-4">
              <div
                class="flex-shrink-0 w-10 h-10 md:w-12 md:h-12 rounded-lg flex items-center justify-center group-hover:scale-110 transition-transform"
                :style="{ backgroundColor: template.iconBg }"
              >
                <i
                  :class="template.icon"
                  class="text-xl md:text-2xl"
                  :style="{ color: template.iconColor }"
                />
              </div>
              <div class="flex-1 min-w-0">
                <h3
                  class="font-bold text-sm md:text-base text-n-slate-12 mb-1 group-hover:text-n-brand transition-colors"
                >
                  {{ template.name }}
                </h3>
                <p class="text-xs text-n-slate-11 line-clamp-2">
                  {{ template.description }}
                </p>
              </div>
            </div>

            <!-- Stages Preview -->
            <div class="space-y-2">
              <p
                class="text-xs font-semibold text-n-slate-9 uppercase tracking-wider"
              >
                {{ template.stages.length }} {{ $t('KANBAN_SETTINGS.STAGES') }}
              </p>
              <div class="flex flex-wrap gap-1.5">
                <div
                  v-for="stage in template.stages.slice(0, 4)"
                  :key="stage.id"
                  class="inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium text-white"
                  :style="{ backgroundColor: stage.color }"
                >
                  {{ stage.name }}
                </div>
                <div
                  v-if="template.stages.length > 4"
                  class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-n-slate-3 text-n-slate-11"
                >
                  {{ `+${template.stages.length - 4}` }}
                </div>
              </div>
            </div>

            <!-- Use Button -->
            <button
              class="w-full mt-3 md:mt-4 px-4 py-2 bg-n-brand text-white rounded-lg font-semibold text-xs md:text-sm hover:bg-n-brand/90 transition-colors opacity-0 group-hover:opacity-100"
            >
              {{ $t('KANBAN_SETTINGS.USE_TEMPLATE') }}
            </button>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div
        class="flex flex-col sm:flex-row items-center justify-between gap-3 p-4 md:p-6 border-t border-n-weak bg-n-slate-1"
      >
        <p class="text-xs md:text-sm text-n-slate-11 text-center sm:text-left">
          {{ `💡 ${$t('KANBAN_SETTINGS.CUSTOMIZE_AFTER_CREATE')}` }}
        </p>
        <button
          class="w-full sm:w-auto px-4 py-2 text-xs md:text-sm font-semibold text-n-slate-12 hover:bg-n-slate-2 rounded-lg transition-colors"
          @click="$emit('close')"
        >
          {{ $t('KANBAN_SETTINGS.CREATE_BLANK_BOARD') }}
        </button>
      </div>
    </div>
  </Modal>
</template>
