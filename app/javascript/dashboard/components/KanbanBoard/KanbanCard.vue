<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { formatDistanceToNow } from 'date-fns';

const props = defineProps({
  conversation: { type: Object, required: true },
});

const store = useStore();
const { t } = useI18n();

const contact = computed(() => props.conversation.meta?.sender);
const assignee = computed(() => props.conversation.meta?.assignee);
const inbox = computed(() =>
  store.getters['inboxes/getInbox'](props.conversation.inbox_id)
);

const timeAgo = computed(() => {
  return formatDistanceToNow(
    new Date(props.conversation.last_activity_at * 1000),
    {
      addSuffix: true,
    }
  );
});

const priorityColor = computed(() => {
  const colors = {
    urgent: 'bg-red-100 text-red-800',
    high: 'bg-orange-100 text-orange-800',
    medium: 'bg-blue-100 text-blue-800',
    low: 'bg-green-100 text-green-800',
  };
  return colors[props.conversation.priority] || 'bg-gray-100 text-gray-800';
});

const dealValue = computed(() => {
  return props.conversation.custom_attributes?.deal_value || 0;
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
    class="flex flex-col gap-2 rounded-lg border border-n-slate-6 bg-white p-3 shadow-sm transition-shadow hover:shadow-md"
  >
    <!-- Cabeçalho com nome e valor -->
    <div class="flex items-start justify-between gap-2">
      <div class="flex-1 min-w-0">
        <h4 class="truncate text-sm font-medium text-n-slate-12">
          {{ contact?.name || t('KANBAN.UNKNOWN_CONTACT') }}
        </h4>
        <p class="truncate text-xs text-n-slate-11">
          {{ contact?.email || contact?.phone_number || '-' }}
        </p>
      </div>
      <div
        v-if="dealValue > 0"
        class="flex-shrink-0 rounded bg-green-50 px-2 py-1 text-xs font-semibold text-green-700"
      >
        {{ formatCurrency(dealValue) }}
      </div>
    </div>

    <!-- Labels -->
    <div v-if="conversation.labels?.length" class="flex flex-wrap gap-1">
      <span
        v-for="label in conversation.labels.slice(0, 3)"
        :key="label"
        class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
        :style="{
          backgroundColor: `${label.color}20`,
          color: label.color,
        }"
      >
        {{ label.title }}
      </span>
      <span
        v-if="conversation.labels.length > 3"
        class="inline-flex items-center rounded-full bg-n-slate-3 px-2 py-0.5 text-xs font-medium text-n-slate-11"
      >
        +{{ conversation.labels.length - 3 }}
      </span>
    </div>

    <!-- Mensagem preview -->
    <p class="line-clamp-2 text-xs text-n-slate-11">
      {{ conversation.messages?.[0]?.content || t('KANBAN.NO_MESSAGES') }}
    </p>

    <!-- Rodapé -->
    <div
      class="flex items-center justify-between gap-2 pt-2 border-t border-n-slate-4"
    >
      <div class="flex items-center gap-2">
        <!-- Inbox -->
        <span
          v-if="inbox"
          class="inline-flex items-center gap-1 text-xs text-n-slate-11"
        >
          <i class="i-lucide-inbox text-sm" />
          {{ inbox.name }}
        </span>

        <!-- Prioridade -->
        <span
          v-if="conversation.priority"
          class="inline-flex items-center rounded px-1.5 py-0.5 text-xs font-medium"
          :class="[priorityColor]"
        >
          {{
            t(
              `CONVERSATION.PRIORITY.OPTIONS.${conversation.priority.toUpperCase()}`
            )
          }}
        </span>
      </div>

      <!-- Tempo e Assignee -->
      <div class="flex items-center gap-2">
        <span class="text-xs text-n-slate-11">
          {{ timeAgo }}
        </span>
        <img
          v-if="assignee?.thumbnail"
          :src="assignee.thumbnail"
          :alt="assignee.name"
          class="h-5 w-5 rounded-full"
          :title="assignee.name"
        />
        <div
          v-else
          class="flex h-5 w-5 items-center justify-center rounded-full bg-n-slate-6 text-xs text-n-slate-11"
          :title="t('KANBAN.UNASSIGNED')"
        >
          ?
        </div>
      </div>
    </div>
  </div>
</template>
