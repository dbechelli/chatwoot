<script setup>
import { ref, computed } from 'vue';
import { 
  format, 
  startOfMonth, 
  endOfMonth, 
  startOfWeek, 
  endOfWeek, 
  eachDayOfInterval, 
  isSameMonth, 
  isSameDay, 
  addMonths, 
  subMonths,
  isToday,
  parseISO
} from 'date-fns';
import { ptBR, enUS } from 'date-fns/locale';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  stages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['openItem']);

const { t, locale } = useI18n();

const currentMonth = ref(new Date());

const currentLocale = computed(() => {
  return locale.value === 'pt_BR' ? ptBR : enUS;
});

const monthTitle = computed(() => {
  const formatted = format(currentMonth.value, 'MMMM yyyy', { locale: currentLocale.value });
  return formatted.charAt(0).toUpperCase() + formatted.slice(1);
});

// Optimization: Pre-calculate items map by date to avoid O(N*30) complexity
const itemsByDateMap = computed(() => {
  const map = {};
  
  props.items.forEach(item => {
    const attrs = item.custom_attributes || {};
    
    // Helper to add item to map
    const addToMap = (dateStr, type, idSuffix) => {
       if (!dateStr) return;
       // Parse once
       try {
         const date = parseISO(dateStr);
         const key = format(date, 'yyyy-MM-dd');
         
         if (!map[key]) map[key] = [];
         
         map[key].push({ 
           ...item, 
           calendarType: type, 
           calendarUniqueId: `${item.id}-${idSuffix}` 
         });
       } catch (e) {
         // Invalid date
       }
    };

    addToMap(attrs.kanban_due_date, 'due', 'due');
    addToMap(attrs.kanban_start_date, 'start', 'start');
    addToMap(attrs.kanban_scheduled_at, 'schedule', 'schedule');
  });

  return map;
});

const calendarDays = computed(() => {
  const monthStart = startOfMonth(currentMonth.value);
  const monthEnd = endOfMonth(currentMonth.value);
  const startDate = startOfWeek(monthStart, { locale: currentLocale.value });
  const endDate = endOfWeek(monthEnd, { locale: currentLocale.value });

  const days = eachDayOfInterval({
    start: startDate,
    end: endDate,
  });

  return days.map(day => {
    const dateKey = format(day, 'yyyy-MM-dd');
    return {
      date: day,
      isCurrentMonth: isSameMonth(day, monthStart),
      isToday: isToday(day),
      items: itemsByDateMap.value[dateKey] || [],
    };
  });
});

const weekDays = computed(() => {
  const now = new Date();
  const weekStart = startOfWeek(now, { locale: currentLocale.value });
  const weekEnd = endOfWeek(now, { locale: currentLocale.value });
  return eachDayOfInterval({ start: weekStart, end: weekEnd }).map(day => 
    format(day, 'EEEE', { locale: currentLocale.value })
  );
});

const nextMonth = () => {
  currentMonth.value = addMonths(currentMonth.value, 1);
};

const prevMonth = () => {
  currentMonth.value = subMonths(currentMonth.value, 1);
};

const jumpToToday = () => {
  currentMonth.value = new Date();
};

const handleItemClick = (item) => {
  emit('openItem', item);
};

</script>

<template>
  <div class="flex h-full w-full min-w-0 flex-1 flex-col overflow-hidden bg-n-surface-1">
    <div class="flex items-center justify-between border-b border-n-weak px-4 py-4 md:px-6">
      <div class="flex items-center gap-4">
        <h2 class="text-lg font-medium capitalize text-n-slate-12">{{ monthTitle }}</h2>
        <div class="inline-flex items-center gap-1 rounded-xl border border-n-weak bg-n-slate-2 p-1">
          <Button sm slate ghost icon="i-lucide-chevron-left" @click="prevMonth" />
          <Button sm slate outline :label="$t('KANBAN.CALENDAR.TODAY') || 'Hoje'" @click="jumpToToday" />
          <Button sm slate ghost icon="i-lucide-chevron-right" @click="nextMonth" />
        </div>
      </div>
    </div>

    <div class="flex min-h-0 flex-1 flex-col overflow-hidden">
      <div class="grid grid-cols-7 border-b border-n-weak bg-n-slate-2/80">
        <div 
          v-for="dayName in weekDays" 
          :key="dayName"
          class="py-2 text-center text-xs font-medium uppercase tracking-wide text-n-slate-10"
        >
          {{ dayName }}
        </div>
      </div>

      <div class="grid min-h-0 flex-1 grid-cols-7 grid-rows-5 overflow-y-auto bg-n-weak/30">
        <div 
          v-for="day in calendarDays" 
          :key="day.date"
          class="group flex min-h-[120px] flex-col gap-1 border-b border-r border-n-weak bg-n-surface-1 p-2 transition-colors hover:bg-n-slate-2/50"
          :class="{
            'bg-n-slate-2/50 text-n-slate-10': !day.isCurrentMonth,
            'bg-n-brand/5': day.isToday
          }"
        >
          <div class="mb-1 flex items-center justify-between">
            <span 
              class="flex h-7 w-7 items-center justify-center rounded-full text-sm font-medium"
              :class="{
                'bg-n-brand text-white': day.isToday,
                'text-n-slate-12': !day.isToday && day.isCurrentMonth
              }"
            >
              {{ format(day.date, 'd') }}
            </span>
            <button 
              v-if="day.isCurrentMonth"
              class="rounded-lg p-1 text-n-slate-10 opacity-0 transition-all hover:bg-n-slate-3 group-hover:opacity-100"
              :title="$t('KANBAN.CALENDAR.ADD_ITEM') || 'Adicionar Item'"
              @click="$emit('openItem', { custom_attributes: { kanban_due_date: format(day.date, 'yyyy-MM-dd') } })"
            >
              <i class="i-lucide-plus text-xs" />
            </button>
          </div>

          <div class="custom-scrollbar max-h-[100px] flex-1 space-y-1 overflow-y-auto">
            <div 
              v-for="item in day.items" 
              :key="item.calendarUniqueId"
              @click.stop="handleItemClick(item)"
              class="group/item rounded-xl border border-n-weak bg-n-surface-1 px-2 py-1.5 text-xs transition-all hover:border-n-brand/30 hover:bg-n-slate-2/50"
              :class="{
                'ring-1 ring-n-ruby-6/50': item.priority === 'urgent',
                'ring-1 ring-n-amber-6/50': item.priority === 'high',
                'ring-1 ring-n-brand/40': item.priority === 'medium',
                'ring-1 ring-n-slate-6/50': item.priority === 'low'
              }"
            >
              <div class="flex min-w-0 items-center gap-1.5">
                 <i v-if="item.calendarType === 'start'" class="i-lucide-calendar-clock shrink-0 text-n-blue-11" title="Início" />
                 <i v-else-if="item.calendarType === 'due'" class="i-lucide-calendar-x shrink-0 text-n-ruby-11" title="Vencimento" />
                 <i v-else-if="item.calendarType === 'schedule'" class="i-lucide-message-square-clock shrink-0 text-n-amber-11" title="Mensagem Agendada" />

                <div class="truncate font-medium text-n-slate-12">
                  {{ item.custom_attributes?.kanban_title || item.meta?.sender?.name || `#${item.id}` }}
                </div>
              </div>
              <div class="mt-0.5 flex items-center justify-between text-[10px] text-n-slate-10">
                <span v-if="item.custom_attributes?.deal_value">R$ {{ item.custom_attributes.deal_value }}</span>
                <span v-if="item.calendarType === 'schedule'" class="ml-auto font-mono text-n-slate-11">
                   {{ item.custom_attributes.kanban_scheduled_at ? format(parseISO(item.custom_attributes.kanban_scheduled_at), 'HH:mm') : '' }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.custom-scrollbar::-webkit-scrollbar {
  width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
  background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
  background-color: #cbd5e1;
  border-radius: 4px;
}
</style>