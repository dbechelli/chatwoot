<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import {
  startOfMonth,
  endOfMonth,
  startOfWeek,
  endOfWeek,
  eachDayOfInterval,
  format,
  addMonths,
  subMonths,
  isSameDay,
  isSameMonth
} from 'date-fns';
import CalendarEventsAPI from '../../api/calendarEvents';

// State
const currentDate = ref(new Date());
const events = ref([]);
const showModal = ref(false);
const activeEvent = ref({
  title: '',
  description: '',
  start_time: '',
  end_time: '',
  notify: false
});
const isEditing = ref(false);

const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

// Computed
const calendarDays = computed(() => {
  const start = startOfWeek(startOfMonth(currentDate.value));
  const end = endOfWeek(endOfMonth(currentDate.value));
  return eachDayOfInterval({ start, end });
});

// Methods
const fetchEvents = async () => {
    try {
        const start = startOfWeek(startOfMonth(currentDate.value)).toISOString();
        const end = endOfWeek(endOfMonth(currentDate.value)).toISOString();
        const response = await CalendarEventsAPI.get({ start_date: start, end_date: end });
        events.value = response.data;
    } catch (error) {
        console.error(error);
    }
};

const nextMonth = () => {
    currentDate.value = addMonths(currentDate.value, 1);
};
const prevMonth = () => {
    currentDate.value = subMonths(currentDate.value, 1);
};

const onDayClick = (day) => {
    activeEvent.value = {
        title: '',
        description: '',
        start_time: format(day, "yyyy-MM-dd'T'HH:mm"),
        end_time: format(day, "yyyy-MM-dd'T'HH:mm"),
        notify: false
    };
    isEditing.value = false;
    showModal.value = true;
};

const onEventClick = (event) => {
    activeEvent.value = { 
        ...event,
        start_time: format(new Date(event.start_time), "yyyy-MM-dd'T'HH:mm"),
        end_time: format(new Date(event.end_time), "yyyy-MM-dd'T'HH:mm"),
        notify: false
     };
    isEditing.value = true;
    showModal.value = true;
};

const saveEvent = async () => {
    try {
        const payload = { calendar_event: activeEvent.value };
        if (isEditing.value) {
            await CalendarEventsAPI.update(activeEvent.value.id, payload);
        } else {
            await CalendarEventsAPI.create(payload);
        }
        showModal.value = false;
        fetchEvents();
    } catch (error) {
        console.error(error);
    }
}

const deleteEvent = async () => {
    if (!confirm('Are you sure?')) return;
    try {
        await CalendarEventsAPI.delete(activeEvent.value.id);
        showModal.value = false;
        fetchEvents();
    } catch (error) {
         console.error(error);
    }
}

watch(currentDate, () => {
    fetchEvents();
});

onMounted(() => {
    fetchEvents();
});

</script>

<template>
  <div class="flex flex-col h-full bg-white dark:bg-slate-900 p-4 overflow-auto">
    <!-- Header -->
    <div class="flex justify-between items-center mb-4">
        <h1 class="text-2xl font-bold dark:text-white">{{ format(currentDate, 'MMMM yyyy') }}</h1>
        <div class="space-x-2">
            <button @click="prevMonth" class="px-3 py-1 bg-slate-100 dark:bg-slate-800 rounded dark:text-white">Prev</button>
             <button @click="nextMonth" class="px-3 py-1 bg-slate-100 dark:bg-slate-800 rounded dark:text-white">Next</button>
        </div>
    </div>

    <!-- Calendar Grid -->
    <div class="grid grid-cols-7 gap-px bg-slate-200 dark:bg-slate-700 border border-slate-200 dark:border-slate-700">
        <!-- Weekdays -->
        <div v-for="day in days" :key="day" class="p-2 text-center font-semibold bg-white dark:bg-slate-900 dark:text-gray-300">
            {{ day }}
        </div>
        
        <!-- Days -->
         <div v-for="date in calendarDays" :key="date" 
            class="min-h-[100px] bg-white dark:bg-slate-900 p-1 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800"
            :class="{ 'opacity-50': !isSameMonth(date, currentDate) }"
            @click="onDayClick(date)"
         >
            <div class="text-right text-sm text-gray-500 dark:text-gray-400 mb-1">
                {{ format(date, 'd') }}
            </div>
            <!-- Events -->
            <div v-for="event in events.filter(e => isSameDay(new Date(e.start_time), date))" :key="event.id"
                class="bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-100 text-xs rounded px-1 py-0.5 mb-1 truncate"
                @click.stop="onEventClick(event)"
            >
                {{ event.title }}
            </div>
         </div>
    </div>

    <!-- Modal (Simple implementation) -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
        <div class="bg-white dark:bg-slate-800 p-6 rounded shadow-lg w-96">
            <h2 class="text-xl font-bold mb-4 dark:text-white">{{ isEditing ? 'Edit Event' : 'Add Event' }}</h2>
            <div class="mb-3">
                <label class="block text-sm font-medium mb-1 dark:text-gray-300">Title</label>
                <input v-model="activeEvent.title" type="text" class="w-full border rounded p-2 dark:bg-slate-700 dark:border-slate-600 dark:text-white" />
            </div>
            <div class="mb-3">
                <label class="block text-sm font-medium mb-1 dark:text-gray-300">Description</label>
                <textarea v-model="activeEvent.description" class="w-full border rounded p-2 dark:bg-slate-700 dark:border-slate-600 dark:text-white"></textarea>
            </div>
            <div class="mb-3">
                <label class="block text-sm font-medium mb-1 dark:text-gray-300">Start</label>
                 <input v-model="activeEvent.start_time" type="datetime-local" class="w-full border rounded p-2 dark:bg-slate-700 dark:border-slate-600 dark:text-white" />
            </div>
            <div class="mb-3">
                <label class="block text-sm font-medium mb-1 dark:text-gray-300">End</label>
                 <input v-model="activeEvent.end_time" type="datetime-local" class="w-full border rounded p-2 dark:bg-slate-700 dark:border-slate-600 dark:text-white" />
            </div>
            <div class="mb-3 flex items-center">
                <input v-model="activeEvent.notify" type="checkbox" id="notify" class="mr-2" />
                <label for="notify" class="text-sm font-medium dark:text-gray-300">Send Notification</label>
            </div>
            <div class="flex justify-end space-x-2">
                 <button v-if="isEditing" @click="deleteEvent" class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 mr-auto">Delete</button>
                <button @click="showModal = false" class="px-4 py-2 border rounded hover:bg-gray-100 dark:hover:bg-gray-700 dark:text-white dark:border-gray-600">Cancel</button>
                <button @click="saveEvent" class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">Save</button>
            </div>
        </div>
    </div>

  </div>
</template>
