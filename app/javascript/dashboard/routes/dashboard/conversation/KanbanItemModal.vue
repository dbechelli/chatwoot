<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  stageId: { type: String, default: '' },
  board: { type: Object, required: true },
  item: { type: Object, default: null }, // If editing existing item
});

const emit = defineEmits(['close', 'save']);
const store = useStore();
const { t } = useI18n();

const isLoading = ref(false);
const searchResults = ref([]);
const isSearching = ref(false);
const newChecklistItem = ref('');

// Form Data
const form = ref({
  title: '',
  description: '',
  value: 0,
  hasValue: false,
  priority: 'medium',
  assignee_id: null,
  conversation_id: null,
  stage_id: props.stageId,
  checklist: [],
});

// Initialize form when item prop changes or modal opens
watch(() => props.item, (newItem) => {
  if (newItem) {
    form.value = {
      title: newItem.custom_attributes?.kanban_title || '',
      description: newItem.custom_attributes?.kanban_description || '',
      value: Number(newItem.custom_attributes?.deal_value) || 0,
      hasValue: !!newItem.custom_attributes?.deal_value,
      priority: newItem.priority || 'medium',
      assignee_id: newItem.meta?.assignee?.id || null,
      conversation_id: newItem.id,
      stage_id: props.stageId,
      checklist: newItem.custom_attributes?.kanban_checklist || [],
    };
  } else {
    // Reset form for new item
    form.value = {
      title: '',
      description: '',
      value: 0,
      hasValue: false,
      priority: 'medium',
      assignee_id: null,
      conversation_id: null,
      stage_id: props.stageId,
      checklist: [],
    };
  }
}, { immediate: true });

// Watch stageId prop change
watch(() => props.stageId, (newVal) => {
  if (newVal && !props.item) form.value.stage_id = newVal;
});

const agents = computed(() => store.getters['agents/getAgents']);

const checklistProgress = computed(() => {
  const total = form.value.checklist.length;
  if (total === 0) return '0/0';
  const done = form.value.checklist.filter(i => i.done).length;
  return `${done}/${total}`;
});

const checklistPercentage = computed(() => {
  const total = form.value.checklist.length;
  if (total === 0) return 0;
  const done = form.value.checklist.filter(i => i.done).length;
  return Math.round((done / total) * 100);
});

const addChecklistItem = () => {
  if (!newChecklistItem.value.trim()) return;
  form.value.checklist.push({
    text: newChecklistItem.value,
    done: false
  });
  newChecklistItem.value = '';
};

const removeChecklistItem = (index) => {
  form.value.checklist.splice(index, 1);
};

const searchConversations = async (query) => {
  if (!query) return;
  isSearching.value = true;
  try {
    const { data } = await window.axios.get(`/api/v1/accounts/${store.getters.getCurrentAccountId}/conversations/search`, {
      params: { q: query }
    });
    searchResults.value = data.payload;
  } catch (error) {
    console.error(error);
  } finally {
    isSearching.value = false;
  }
};

const selectConversation = (conv) => {
  form.value.conversation_id = conv.id;
  // Auto-fill title if empty
  if (!form.value.title) {
    form.value.title = `Negociação #${conv.id}`;
  }
  searchResults.value = [];
};

const getPriorityClasses = (p) => {
  const map = {
    low: 'bg-slate-100 text-slate-600 border-slate-200',
    medium: 'bg-blue-50 text-blue-600 border-blue-200',
    high: 'bg-orange-50 text-orange-600 border-orange-200',
    urgent: 'bg-red-50 text-red-600 border-red-200',
  };
  return map[p];
};

const handleSave = async () => {
  if (!form.value.conversation_id) {
    return;
  }

  isLoading.value = true;
  try {
    const conversationId = form.value.conversation_id;
    
    // 1. Update Custom Attributes
    const customAttributes = {
      kanban_title: form.value.title,
      kanban_description: form.value.description,
      deal_value: form.value.hasValue ? form.value.value : 0,
      kanban_checklist: form.value.checklist, // Save checklist
      [props.board.customAttributeKey]: form.value.stage_id,
    };

    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes,
    });

    // 2. Update Priority
    if (form.value.priority) {
      await store.dispatch('updateConversation', {
        conversationId,
        priority: form.value.priority,
      });
    }

    // 3. Update Assignee
    if (form.value.assignee_id) {
      await store.dispatch('assignAgent', {
        conversationId,
        agentId: form.value.assignee_id,
      });
    }

    emit('save');
    emit('close');
  } catch (error) {
    console.error(error);
  } finally {
    isLoading.value = false;
  }
};

</script>

<template>
  <Modal :show="show" :on-close="() => emit('close')" size="lg">
    <div class="flex flex-col h-[80vh] bg-white rounded-lg shadow-xl overflow-hidden">
      <!-- Header -->
      <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100">
        <div class="flex items-center gap-3">
          <div class="h-8 w-8 rounded-full bg-blue-50 flex items-center justify-center text-blue-600">
            <i class="i-lucide-trello text-lg" />
          </div>
          <div>
            <h2 class="text-lg font-bold text-slate-800">
              {{ form.conversation_id ? 'Editar Item' : 'Novo Item' }}
            </h2>
            <p class="text-xs text-slate-500 font-medium">
              {{ form.conversation_id ? `#${form.conversation_id}` : 'Criando novo card' }}
            </p>
          </div>
        </div>
        <button 
          @click="emit('close')"
          class="p-2 hover:bg-slate-100 rounded-full text-slate-400 hover:text-slate-600 transition-colors"
        >
          <i class="i-lucide-x text-lg" />
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto p-6 space-y-6">
        <!-- Title -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">Título do Item</label>
          <input
            v-model="form.title"
            type="text"
            placeholder="Ex: Negociação Empresa X"
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all"
          />
        </div>

        <!-- Description -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">Descrição</label>
          <textarea
            v-model="form.description"
            rows="3"
            placeholder="Detalhes sobre esta oportunidade..."
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all resize-none"
          />
        </div>

        <!-- Value & Priority Row -->
        <div class="grid grid-cols-2 gap-6">
          <!-- Value -->
          <div class="space-y-1.5">
            <div class="flex items-center justify-between">
              <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">Valor do Deal</label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" v-model="form.hasValue" class="rounded border-slate-300 text-blue-600 focus:ring-blue-500 h-3 w-3" />
                <span class="text-[10px] font-bold text-slate-500 uppercase">Ativar</span>
              </label>
            </div>
            <div class="relative">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-sm font-bold">R$</span>
              <input
                v-model="form.value"
                type="number"
                :disabled="!form.hasValue"
                class="w-full pl-9 pr-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm font-bold text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              />
            </div>
          </div>

          <!-- Priority -->
          <div class="space-y-1.5">
            <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">Prioridade</label>
            <div class="flex gap-2">
              <button
                v-for="p in ['low', 'medium', 'high', 'urgent']"
                :key="p"
                @click="form.priority = p"
                class="flex-1 py-2 rounded-lg text-xs font-bold border transition-all capitalize"
                :class="form.priority === p ? getPriorityClasses(p) : 'border-slate-200 text-slate-500 hover:bg-slate-50'"
              >
                {{ p }}
              </button>
            </div>
          </div>
        </div>

        <!-- Checklist Section -->
        <div class="space-y-3 pt-4 border-t border-slate-100">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold text-slate-700 uppercase tracking-wider flex items-center gap-2">
              <i class="i-lucide-check-square text-slate-400" />
              Checklist
            </label>
            <span class="text-xs font-medium text-slate-500">
              {{ checklistProgress }}
            </span>
          </div>

          <!-- Progress Bar -->
          <div class="h-1.5 w-full bg-slate-100 rounded-full overflow-hidden">
            <div 
              class="h-full bg-blue-500 transition-all duration-500 ease-out"
              :style="{ width: checklistPercentage + '%' }"
            />
          </div>

          <!-- Add Item -->
          <div class="flex gap-2">
            <input
              v-model="newChecklistItem"
              @keydown.enter.prevent="addChecklistItem"
              type="text"
              placeholder="Adicionar item ao checklist..."
              class="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-md text-sm focus:outline-none focus:border-blue-500"
            />
            <button 
              @click="addChecklistItem"
              :disabled="!newChecklistItem"
              class="px-4 py-2 bg-slate-100 text-slate-600 rounded-md text-sm font-bold hover:bg-slate-200 disabled:opacity-50"
            >
              Adicionar
            </button>
          </div>

          <!-- List -->
          <div class="space-y-1">
            <div 
              v-for="(item, index) in form.checklist" 
              :key="index"
              class="group flex items-center gap-3 p-2 hover:bg-slate-50 rounded-md transition-colors"
            >
              <input 
                type="checkbox" 
                v-model="item.done"
                class="rounded border-slate-300 text-blue-600 focus:ring-blue-500 h-4 w-4 cursor-pointer"
              />
              <input
                v-model="item.text"
                class="flex-1 bg-transparent border-none p-0 text-sm text-slate-700 focus:ring-0"
                :class="{ 'line-through text-slate-400': item.done }"
              />
              <button 
                @click="removeChecklistItem(index)"
                class="opacity-0 group-hover:opacity-100 p-1 text-slate-400 hover:text-red-500 transition-all"
              >
                <i class="i-lucide-trash-2 text-xs" />
              </button>
            </div>
            <div v-if="form.checklist.length === 0" class="text-center py-4 text-sm text-slate-400 italic">
              Nenhum item no checklist
            </div>
          </div>
        </div>

        <!-- Conversation Link -->
        <div class="space-y-1.5 pt-4 border-t border-slate-100">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">Vincular Conversa</label>
          
          <div v-if="!form.conversation_id" class="relative">
            <i class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              placeholder="Buscar por nome, email ou ID..."
              class="w-full pl-9 pr-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
              @input="e => searchConversations(e.target.value)"
            />
            
            <!-- Search Results -->
            <div v-if="searchResults.length > 0" class="absolute z-10 w-full mt-1 bg-white border border-slate-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
              <button
                v-for="conv in searchResults"
                :key="conv.id"
                @click="selectConversation(conv)"
                class="w-full text-left px-4 py-2 hover:bg-slate-50 flex items-center justify-between group"
              >
                <div>
                  <div class="font-medium text-slate-800 text-sm">#{{ conv.id }} - {{ conv.meta?.sender?.name || 'Sem nome' }}</div>
                  <div class="text-xs text-slate-500">{{ conv.messages?.[0]?.content?.substring(0, 40) }}...</div>
                </div>
                <i class="i-lucide-link text-slate-300 group-hover:text-blue-500" />
              </button>
            </div>
          </div>

          <div v-else class="flex items-center justify-between p-3 bg-blue-50 border border-blue-100 rounded-lg">
            <div class="flex items-center gap-3">
              <div class="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold text-xs">
                #{{ form.conversation_id }}
              </div>
              <div>
                <div class="text-sm font-bold text-slate-800">Conversa Vinculada</div>
                <div class="text-xs text-slate-500">Clique em salvar para confirmar as alterações</div>
              </div>
            </div>
            <button 
              @click="form.conversation_id = null"
              class="text-xs font-bold text-red-500 hover:text-red-600 hover:underline"
            >
              Desvincular
            </button>
          </div>
        </div>

        <!-- Agent -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">Agente Responsável</label>
          <select
            v-model="form.assignee_id"
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
          >
            <option :value="null">Sem agente</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </div>
      </div>

      <!-- Footer -->
      <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end gap-3">
        <button
          @click="emit('close')"
          class="px-4 py-2 text-sm font-bold text-slate-600 hover:text-slate-800 hover:bg-slate-200 rounded-lg transition-colors"
        >
          Cancelar
        </button>
        <button
          @click="handleSave"
          :disabled="isLoading || !form.conversation_id"
          class="px-6 py-2 text-sm font-bold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-sm shadow-blue-200 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          <i v-if="isLoading" class="i-lucide-loader-2 animate-spin" />
          {{ isLoading ? 'Salvando...' : 'Salvar Item' }}
        </button>
      </div>
    </div>
  </Modal>
</template>
