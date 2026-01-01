<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { formatDistanceToNow } from 'date-fns';
import { ptBR } from 'date-fns/locale'; // Opcional: para forçar o tempo em português

const props = defineProps({
  conversation: { type: Object, required: true },
  visibleAttributes: { type: Array, default: () => [] },
});

const store = useStore();
const { t } = useI18n();

const contact = computed(() => props.conversation.meta?.sender);
const assignee = computed(() => props.conversation.meta?.assignee);
const inbox = computed(() =>
  store.getters['inboxes/getInbox'](props.conversation.inbox_id)
);
const allAttributes = computed(() => store.getters['attributes/getConversationAttributes']);

const displayAttributes = computed(() => {
  if (!props.visibleAttributes.length) return [];
  const attributes = props.conversation.custom_attributes || {};
  
  return props.visibleAttributes.map(key => {
    const def = allAttributes.value.find(a => a.attributeKey === key);
    const value = attributes[key];
    if (value === undefined || value === null || value === '') return null;
    
    return {
      key,
      label: def ? def.attributeDisplayName : key,
      value,
    };
  }).filter(Boolean);
});

const timeAgo = computed(() => {
  return formatDistanceToNow(
    new Date(props.conversation.last_activity_at * 1000),
    {
      addSuffix: true,
      locale: ptBR, // Garante que apareça "há 2 minutos"
    }
  );
});

const priorityColor = computed(() => {
  const colors = {
    urgent: 'bg-red-50 text-red-700 border-red-200',
    high: 'bg-orange-50 text-orange-700 border-orange-200',
    medium: 'bg-blue-50 text-blue-700 border-blue-200',
    low: 'bg-green-50 text-green-700 border-green-200',
  };
  return colors[props.conversation.priority] || 'bg-slate-50 text-slate-600 border-slate-200';
});

const dealValue = computed(() => {
  return props.conversation.custom_attributes?.deal_value || 0;
});

const kanbanTitle = computed(() => {
  return props.conversation.custom_attributes?.kanban_title || contact.value?.name || t('KANBAN.UNKNOWN_CONTACT');
});

const kanbanDescription = computed(() => {
  return props.conversation.custom_attributes?.kanban_description;
});

const checklistProgress = computed(() => {
  const checklist = props.conversation.custom_attributes?.kanban_checklist || [];
  if (!Array.isArray(checklist) || checklist.length === 0) return null;
  
  const total = checklist.length;
  const done = checklist.filter(i => i.done).length;
  return { done, total };
});

const formatCurrency = value => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);
};
</script>

<template>
  <div
    class="group relative flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm transition-all duration-200 hover:-translate-y-1 hover:shadow-md hover:border-blue-300 cursor-pointer"
    @contextmenu.prevent="$emit('contextmenu', { event: $event, conversation })"
  >
    <div 
      v-if="conversation.priority === 'urgent'" 
      class="absolute left-0 top-4 bottom-4 w-1 rounded-r-full bg-red-500"
    ></div>

    <div class="flex items-start justify-between gap-2">
      <div class="flex-1 min-w-0">
        <h4 class="truncate text-sm font-bold text-slate-900 group-hover:text-blue-600 transition-colors">
          {{ kanbanTitle }}
        </h4>
        <div class="flex items-center gap-1 mt-0.5">
          <i class="i-lucide-phone text-[10px] text-slate-400" v-if="contact?.phone_number" />
          <p class="truncate text-xs font-medium text-slate-500">
            {{ contact?.phone_number || contact?.email || '-' }}
          </p>
        </div>
      </div>
      
      <div
        v-if="dealValue > 0"
        class="flex-shrink-0 rounded-lg bg-emerald-50 px-2.5 py-1 text-xs font-bold text-emerald-700 border border-emerald-100 shadow-sm"
      >
        {{ formatCurrency(dealValue) }}
      </div>
    </div>

    <div v-if="kanbanDescription" class="text-xs text-slate-600 line-clamp-2">
      {{ kanbanDescription }}
    </div>

    <!-- Custom Attributes -->
    <div v-if="displayAttributes.length > 0" class="flex flex-col gap-1.5">
      <div 
        v-for="attr in displayAttributes" 
        :key="attr.key"
        class="flex items-center justify-between text-xs"
      >
        <span class="text-slate-500 font-medium">{{ attr.label }}:</span>
        <span class="text-slate-700 font-semibold truncate max-w-[120px]" :title="attr.value">
          {{ attr.value }}
        </span>
      </div>
    </div>

    <div v-if="conversation.labels?.length" class="flex flex-wrap gap-1.5">
      <span
        v-for="label in conversation.labels.slice(0, 3)"
        :key="label"
        class="inline-flex items-center rounded-md border px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider"
        :style="{
          backgroundColor: `${label.color}15`,
          color: label.color,
          borderColor: `${label.color}30`,
        }"
      >
        {{ label.title }}
      </span>
      <span
        v-if="conversation.labels.length > 3"
        class="inline-flex items-center rounded-md bg-slate-100 px-2 py-0.5 text-[10px] font-bold text-slate-500 border border-slate-200"
      >
        +{{ conversation.labels.length - 3 }}
      </span>
    </div>

    <div class="relative bg-slate-50 rounded-lg p-2 border border-slate-100">
      <p class="line-clamp-2 text-xs leading-relaxed text-slate-600 italic">
        "{{ conversation.messages?.[0]?.content || t('KANBAN.NO_MESSAGES') }}"
      </p>
    </div>

    <div
      class="flex items-center justify-between gap-2 pt-3 border-t border-slate-100 mt-1"
    >
      <div class="flex flex-wrap items-center gap-2">
        <span
          v-if="inbox"
          class="inline-flex items-center gap-1 text-[11px] font-semibold text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded"
        >
          <i class="i-lucide-message-circle text-xs text-blue-500" />
          {{ inbox.name }}
        </span>

        <span
          v-if="checklistProgress"
          class="inline-flex items-center gap-1 text-[11px] font-semibold text-slate-600 bg-slate-100 px-1.5 py-0.5 rounded border border-slate-200"
          :class="{ 'bg-green-50 text-green-700 border-green-200': checklistProgress.done === checklistProgress.total }"
          :title="`${checklistProgress.done}/${checklistProgress.total} itens concluídos`"
        >
          <i class="i-lucide-check-square text-xs" />
          {{ checklistProgress.done }}/{{ checklistProgress.total }}
        </span>

        <span
          v-if="conversation.priority"
          class="inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-bold uppercase border shadow-sm"
          :class="[priorityColor]"
        >
          {{
            t(`CONVERSATION.PRIORITY.OPTIONS.${conversation.priority.toUpperCase()}`)
          }}
        </span>
      </div>

      <div class="flex items-center gap-2 flex-shrink-0">
        <span class="text-[10px] font-medium text-slate-400 whitespace-nowrap">
          {{ timeAgo }}
        </span>
        
        <div class="relative">
          <img
            v-if="assignee?.thumbnail"
            :src="assignee.thumbnail"
            :alt="assignee.name"
            class="h-6 w-6 rounded-full border-2 border-white shadow-sm object-cover"
            :title="assignee.name"
          />
          <div
            v-else
            class="flex h-6 w-6 items-center justify-center rounded-full bg-blue-100 border-2 border-white shadow-sm text-[10px] font-bold text-blue-600"
            :title="t('KANBAN.UNASSIGNED')"
          >
            <i class="i-lucide-user text-[12px]" />
          </div>
          <div class="absolute -bottom-0.5 -right-0.5 h-2 w-2 rounded-full bg-emerald-500 border border-white"></div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Efeito de destaque no hover para as labels */
span:hover {
  filter: brightness(0.9);
  transition: filter 0.2s;
}

/* Garante que o line-clamp funcione em todos os browsers */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
