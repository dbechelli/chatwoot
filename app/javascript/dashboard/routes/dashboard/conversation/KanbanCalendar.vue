<script setup>
import { ref, computed, onMounted } from 'vue';
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
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import KanbanCard from 'dashboard/components/KanbanBoard/KanbanCard.vue';

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

const store = useStore();
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

const getStageColor = (stageId) => {
  // Try to find stage
  // Since stage prop is array of stages, mapped by id usually in parent
  // Assuming stage info is not directly on item, but item has stage_id
  // But props.stages is available
  // Let's just return a generic color or try to match if we can
  return 'bg-woot-500';
};

</script>

<template>
  <div class="flex flex-col h-full bg-white rounded-lg shadow-sm border border-slate-200 overflow-hidden">
    <!-- Header -->
    <div class="flex items-center justify-between p-4 border-b border-slate-100">
      <div class="flex items-center gap-4">
        <h2 class="text-lg font-bold text-slate-800 capitalize">{{ monthTitle }}</h2>
        <div class="flex items-center bg-slate-100 rounded-lg p-1">
          <button @click="prevMonth" class="p-1 hover:bg-white hover:shadow-sm rounded-md transition-all text-slate-600">
            <i class="i-lucide-chevron-left text-lg" />
          </button>
          <button @click="jumpToToday" class="px-3 py-1 text-xs font-bold text-slate-600 hover:text-woot-600 transition-colors">
            {{ $t('KANBAN.CALENDAR.TODAY') || 'Hoje' }}
          </button>
          <button @click="nextMonth" class="p-1 hover:bg-white hover:shadow-sm rounded-md transition-all text-slate-600">
            <i class="i-lucide-chevron-right text-lg" />
          </button>
        </div>
      </div>
      
      <!-- Statistics for the month could go here -->
    </div>

    <!-- Calendar Grid -->
    <div class="flex-1 flex flex-col overflow-hidden">
      <!-- Week headers -->
      <div class="grid grid-cols-7 border-b border-slate-200 bg-slate-50">
        <div 
          v-for="dayName in weekDays" 
          :key="dayName"
          class="py-2 text-center text-xs font-bold text-slate-500 uppercase tracking-wider"
        >
          {{ dayName }}
        </div>
      </div>

      <!-- Days -->
      <div class="flex-1 grid grid-cols-7 grid-rows-5 overflow-y-auto">
        <div 
          v-for="day in calendarDays" 
          :key="day.date"
          class="min-h-[120px] border-b border-r border-slate-100 p-2 transition-colors hover:bg-slate-50 group flex flex-col gap-1"
          :class="{
            'bg-slate-50/50 text-slate-400': !day.isCurrentMonth,
            'bg-woot-25/30': day.isToday
          }"
        >
          <div class="flex items-center justify-between mb-1">
            <span 
              class="text-sm font-medium w-7 h-7 flex items-center justify-center rounded-full"
              :class="{
                'bg-woot-500 text-white shadow-md': day.isToday,
                'text-slate-700': !day.isToday && day.isCurrentMonth
              }"
            >
              {{ format(day.date, 'd') }}
            </span>
            <button 
              v-if="day.isCurrentMonth"
              class="opacity-0 group-hover:opacity-100 p-1 hover:bg-slate-200 rounded text-slate-400 transition-all"
              :title="$t('KANBAN.CALENDAR.ADD_ITEM') || 'Adicionar Item'"
              @click="$emit('openItem', { custom_attributes: { kanban_due_date: format(day.date, 'yyyy-MM-dd') } })"
            >
              <i class="i-lucide-plus text-xs" />
            </button>
          </div>

          <!-- Items list for the day -->
          <div class="flex-1 space-y-1 overflow-y-auto max-h-[100px] custom-scrollbar">
            <div 
              v-for="item in day.items" 
              :key="item.calendarUniqueId"
              @click.stop="handleItemClick(item)"
              class="px-2 py-1.5 bg-white border border-slate-200 rounded shadow-sm text-xs cursor-pointer hover:border-woot-300 hover:shadow-md transition-all truncate border-l-4 group/item"
              :class="{
                'border-l-red-500': item.priority === 'urgent',
                'border-l-orange-400': item.priority === 'high',
                'border-l-woot-500': item.priority === 'medium',
                'border-l-slate-400': item.priority === 'low'
              }"
            >
              <div class="flex items-center gap-1.5 min-w-0">
                 <!-- Icon based on type -->
                 <i v-if="item.calendarType === 'start'" class="i-lucide-calendar-clock text-blue-500 flex-shrink-0" title="Início" />
                 <i v-else-if="item.calendarType === 'due'" class="i-lucide-calendar-x text-red-500 flex-shrink-0" title="Vencimento" />
                 <i v-else-if="item.calendarType === 'schedule'" class="i-lucide-message-square-clock text-amber-500 flex-shrink-0" title="Mensagem Agendada" />

                <div class="font-medium text-slate-700 truncate">
                  {{ item.custom_attributes?.kanban_title || item.meta?.sender?.name || `#${item.id}` }}
                </div>
              </div>
              <!-- Optional: show time if we had it, or value -->
              <div class="flex justify-between items-center text-[10px] text-slate-500 mt-0.5">
                <span v-if="item.custom_attributes?.deal_value">R$ {{ item.custom_attributes.deal_value }}</span>
                <span v-if="item.calendarType === 'schedule'" class="ml-auto font-mono">
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