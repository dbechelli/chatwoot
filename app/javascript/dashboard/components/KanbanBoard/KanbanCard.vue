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

const emit = defineEmits(['contextmenu']);

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
    urgent: 'border-n-ruby-7 bg-n-ruby-3 text-n-ruby-11',
    high: 'border-n-amber-7 bg-n-amber-3 text-n-amber-11',
    medium: 'border-n-brand/20 bg-n-brand/10 text-n-blue-11',
    low: 'border-n-teal-7 bg-n-teal-3 text-n-teal-11',
  };
  return colors[props.conversation.priority] || 'border-n-weak bg-n-slate-2 text-n-slate-11';
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

const dueDate = computed(() => {
  return props.conversation.custom_attributes?.kanban_due_date;
});

const isOverdue = computed(() => {
  if (!dueDate.value) return false;
  return new Date(dueDate.value) < new Date();
});

const isDueSoon = computed(() => {
  if (!dueDate.value || isOverdue.value) return false;
  const daysUntilDue = Math.ceil((new Date(dueDate.value) - new Date()) / (1000 * 60 * 60 * 24));
  return daysUntilDue <= 3 && daysUntilDue > 0;
});

const formatDate = (dateStr) => {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  return date.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' });
};

const formatCurrency = value => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);
};
</script>

<template>
  <div
    class="group relative flex flex-col gap-3 rounded-2xl border border-n-weak bg-n-surface-1 p-3 transition-all duration-200 hover:border-n-brand/30 hover:bg-n-slate-2/40"
    @contextmenu.prevent="$emit('contextmenu', { event: $event, conversation })"
  >
    <div
      v-if="conversation.priority === 'urgent'"
      class="absolute left-0 top-4 bottom-4 w-1 rounded-r-full bg-n-ruby-9"
    />
    
    <div class="flex items-start justify-between gap-2">
      <div class="flex-1 min-w-0">
        <h4 class="truncate text-sm font-medium text-n-slate-12 transition-colors group-hover:text-n-blue-11">
          {{ kanbanTitle }}
        </h4>
        <div v-if="contact" class="mt-0.5 flex items-center gap-1">
          <i class="i-lucide-phone text-[10px] text-n-slate-10" v-if="contact.phone_number" />
          <p class="truncate text-xs font-medium text-n-slate-11">
            {{ contact.phone_number || contact.email || '-' }}
          </p>
        </div>
      </div>
      
      <div
        v-if="dealValue > 0"
        class="flex-shrink-0 rounded-xl border border-n-teal-6/30 bg-n-teal-3/50 px-2.5 py-1 text-xs font-medium text-n-teal-11"
      >
        {{ formatCurrency(dealValue) }}
      </div>
    </div>

    <div v-if="kanbanDescription" class="line-clamp-2 text-xs text-n-slate-11">
      {{ kanbanDescription }}
    </div>

    <div v-if="displayAttributes.length > 0" class="flex flex-col gap-1.5">
      <div 
        v-for="attr in displayAttributes" 
        :key="attr.key"
        class="flex items-center justify-between text-xs"
      >
        <span class="font-medium text-n-slate-10">{{ attr.label }}:</span>
        <span class="max-w-[120px] truncate font-medium text-n-slate-12" :title="attr.value">
          {{ attr.value }}
        </span>
      </div>
    </div>

    <div v-if="conversation.labels?.length" class="flex flex-wrap gap-1.5">
      <span
        v-for="label in conversation.labels.slice(0, 3)"
        :key="label"
        class="inline-flex items-center rounded-lg border px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide"
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
        class="inline-flex items-center rounded-lg border border-n-weak bg-n-slate-2 px-2 py-0.5 text-[10px] font-medium text-n-slate-11"
      >
        +{{ conversation.labels.length - 3 }}
      </span>
    </div>

    <div class="relative rounded-xl border border-n-weak bg-n-slate-2/60 p-2.5">
      <p class="line-clamp-2 text-xs leading-relaxed text-n-slate-11">
        "{{ conversation.messages?.[0]?.content || t('KANBAN.NO_MESSAGES') }}"
      </p>
    </div>

    <div
      class="mt-1 flex items-center justify-between gap-2 border-t border-n-weak pt-3"
    >
      <div class="flex flex-wrap items-center gap-2">
        <span
          v-if="dueDate"
          class="inline-flex items-center gap-1 rounded-lg border px-1.5 py-0.5 text-[11px] font-medium"
          :class="[
            isOverdue ? 'border-n-ruby-7 bg-n-ruby-3 text-n-ruby-11' : 
            isDueSoon ? 'border-n-amber-7 bg-n-amber-3 text-n-amber-11' : 
            'border-n-weak bg-n-slate-2 text-n-slate-11'
          ]"
        >
          <i class="i-lucide-calendar text-xs" />
          {{ formatDate(dueDate) }}
        </span>

        <span
          v-if="inbox"
          class="inline-flex items-center gap-1 rounded-lg bg-n-slate-2 px-1.5 py-0.5 text-[11px] font-medium text-n-slate-11"
        >
          <i class="i-lucide-message-circle text-xs text-n-brand" />
          {{ inbox.name }}
        </span>

        <span
          v-if="checklistProgress"
          class="inline-flex items-center gap-1 rounded-lg border border-n-weak bg-n-slate-2 px-1.5 py-0.5 text-[11px] font-medium text-n-slate-11"
          :class="{ 'border-n-teal-7 bg-n-teal-3 text-n-teal-11': checklistProgress.done === checklistProgress.total }"
          :title="`${checklistProgress.done}/${checklistProgress.total} itens concluídos`"
        >
          <i class="i-lucide-check-square text-xs" />
          {{ checklistProgress.done }}/{{ checklistProgress.total }}
        </span>

        <span
          v-if="conversation.priority"
          class="inline-flex items-center rounded-lg border px-1.5 py-0.5 text-[10px] font-medium uppercase"
          :class="[priorityColor]"
        >
          {{
            t(`CONVERSATION.PRIORITY.OPTIONS.${conversation.priority.toUpperCase()}`)
          }}
        </span>
      </div>

      <div class="flex items-center gap-2 flex-shrink-0">
        <span class="whitespace-nowrap text-[10px] font-medium text-n-slate-10">
          {{ timeAgo }}
        </span>
        
        <div class="relative">
          <img
            v-if="assignee?.thumbnail"
            :src="assignee.thumbnail"
            :alt="assignee.name"
            class="h-6 w-6 rounded-full border-2 border-n-surface-1 object-cover"
            :title="assignee.name"
          />
          <div
            v-else
            class="flex h-6 w-6 items-center justify-center rounded-full border-2 border-n-surface-1 bg-n-brand/10 text-[10px] font-medium text-n-blue-11"
            :title="t('KANBAN.UNASSIGNED')"
          >
            <i class="i-lucide-user text-[12px]" />
          </div>
          <div class="absolute -bottom-0.5 -right-0.5 h-2 w-2 rounded-full border border-n-surface-1 bg-n-teal-9"></div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
span:hover {
  filter: brightness(0.9);
  transition: filter 0.2s;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
