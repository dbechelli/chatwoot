<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  stageId: { type: String, default: '' },
  board: { type: Object, required: true },
  item: { type: Object, default: null }, // If editing existing item
  conversationId: { type: [Number, String], default: null }, // Context conversation
});

const emit = defineEmits(['close', 'save']);
const store = useStore();
const { t } = useI18n();

const isLoading = ref(false);
const searchResults = ref([]);
const isSearching = ref(false);
const newChecklistItem = ref('');
const selectedConversation = ref(null);

// Form Data
const form = ref({
  title: '',
  description: '',
  notes: '',
  value: 0,
  hasValue: false,
  priority: 'medium',
  assignee_id: null,
  conversation_id: null,
  stage_id: props.stageId,
  checklist: [],
  custom_attributes: {},
});



const agents = computed(() => store.getters['agents/getAgents']);

const boardCustomAttributeKey = computed(() => props.board.customAttributeKey || 'sales_stage');

const customAttributes = computed(() => {
  const allAttributes = store.getters['attributes/getAttributesByModel']('conversation_attribute') || [];
  const ignoredKeys = ['kanban_title', 'kanban_description', 'kanban_notes', 'deal_value', 'kanban_checklist', boardCustomAttributeKey.value];
  return allAttributes.filter(attr => !ignoredKeys.includes(attr.attribute_key));
});

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

// Initialize form when item prop changes or modal opens
watch(() => props.item, (newItem) => {
  selectedConversation.value = null;
  // Check if newItem exists and has an ID (it might be a Proxy, so we check properties)
  if (newItem && (newItem.id || newItem.display_id)) {
    const conversationId = newItem.id || newItem.display_id;
    
    // Extract dynamic custom attributes
    const itemAttributes = newItem.custom_attributes || {};
    const dynamicAttributes = {};
    if (customAttributes.value && customAttributes.value.length) {
      customAttributes.value.forEach(attr => {
        dynamicAttributes[attr.attribute_key] = itemAttributes[attr.attribute_key] || '';
      });
    }

    form.value = {
      title: newItem.custom_attributes?.kanban_title || newItem.meta?.sender?.name || `Conversa #${conversationId}`,
      description: newItem.custom_attributes?.kanban_description || '',
      notes: newItem.custom_attributes?.kanban_notes || '',
      value: Number(newItem.custom_attributes?.deal_value) || 0,
      hasValue: !!newItem.custom_attributes?.deal_value,
      priority: newItem.priority || 'medium',
      assignee_id: newItem.meta?.assignee?.id || null,
      conversation_id: conversationId,
      stage_id: props.stageId,
      checklist: newItem.custom_attributes?.kanban_checklist || [],
      custom_attributes: dynamicAttributes,
    };
  } else {
    // Reset form for new item
    const dynamicAttributes = {};
    if (customAttributes.value && customAttributes.value.length) {
      customAttributes.value.forEach(attr => {
        dynamicAttributes[attr.attribute_key] = '';
      });
    }

    form.value = {
      title: '',
      description: '',
      notes: '',
      value: 0,
      hasValue: false,
      priority: 'medium',
      assignee_id: null,
      conversation_id: props.conversationId || null,
      stage_id: props.stageId,
      checklist: [],
      custom_attributes: dynamicAttributes,
    };
    
    // If we have a conversationId but no item, we might want to fetch the conversation details
    // to pre-fill the title (e.g. with contact name)
    if (props.conversationId) {
      // We can try to find it in the store first
      const chat = store.getters['getConversation'](props.conversationId);
      if (chat) {
        selectConversation(chat);
      }
    }
  }
}, { immediate: true, deep: true });

// Watch stageId prop change
watch(() => props.stageId, (newVal) => {
  if (newVal && !props.item) form.value.stage_id = newVal;
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
  selectedConversation.value = conv;
  form.value.conversation_id = conv.id;
  
  const attrs = conv.custom_attributes || {};

  // Title: Use existing kanban title, or keep current form title, or default to contact name/ID
  form.value.title = attrs.kanban_title || form.value.title || conv.meta?.sender?.name || `Conversa #${conv.id}`;

  // Description & Notes: Use existing if present, else keep form, else empty
  form.value.description = attrs.kanban_description || form.value.description || '';
  form.value.notes = attrs.kanban_notes || form.value.notes || '';

  // Value
  if (attrs.deal_value) {
    form.value.value = Number(attrs.deal_value);
    form.value.hasValue = true;
  }

  // Checklist
  if (attrs.kanban_checklist && attrs.kanban_checklist.length > 0) {
    form.value.checklist = attrs.kanban_checklist;
  }

  // Dynamic attributes
  customAttributes.value.forEach(attr => {
    if (attrs[attr.attribute_key]) {
      form.value.custom_attributes[attr.attribute_key] = attrs[attr.attribute_key];
    }
  });

  searchResults.value = [];
};

const getPriorityClasses = (p) => {
  const map = {
    low: 'bg-slate-100 text-slate-600 border-slate-200',
    medium: 'bg-woot-50 text-woot-600 border-woot-200',
    high: 'bg-orange-50 text-orange-600 border-orange-200',
    urgent: 'bg-red-50 text-red-600 border-red-200',
  };
  return map[p];
};

const handleSave = async () => {
  // Fallback: if form.conversation_id is missing but we have an item, use it
  if (!form.value.conversation_id && props.item?.id) {
    form.value.conversation_id = props.item.id;
  }

  if (!form.value.conversation_id) {
    useAlert(t('KANBAN.MODAL.NO_CONVERSATION_SELECTED') || 'Selecione uma conversa para continuar');
    return;
  }

  isLoading.value = true;
  try {
    const conversationId = form.value.conversation_id;
    
    // Determine existing attributes to preserve
    let existingAttributes = {};
    if (props.item) {
      existingAttributes = props.item.custom_attributes || {};
    } else if (selectedConversation.value) {
      existingAttributes = selectedConversation.value.custom_attributes || {};
    }

    // 1. Update Custom Attributes
    const customAttributes = {
      ...existingAttributes,
      kanban_title: form.value.title,
      kanban_description: form.value.description,
      kanban_notes: form.value.notes,
      deal_value: form.value.hasValue ? form.value.value : 0,
      kanban_checklist: form.value.checklist, // Save checklist
      [boardCustomAttributeKey.value]: form.value.stage_id,
      ...form.value.custom_attributes,
    };

    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes,
    });

    // 2. Update Priority via dedicated action (avoids missing meta/sender shape)
    if (form.value.priority) {
      await store.dispatch('assignPriority', {
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

    useAlert(t('KANBAN.MODAL.SUCCESS_MESSAGE') || 'Item salvo com sucesso');
    emit('save');
    emit('close');
  } catch (error) {
    console.error(error);
    useAlert(t('KANBAN.MODAL.ERROR_MESSAGE') || 'Erro ao salvar item');
  } finally {
    isLoading.value = false;
  }
};

</script>

<template>
  <Modal :show="show" :on-close="() => emit('close')" size="lg" :show-close-button="false">
    <div class="flex flex-col h-full bg-white rounded-md overflow-hidden max-h-[85vh]">
      <!-- Header -->
      <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50">
        <div class="flex items-center gap-3">
          <div class="h-8 w-8 rounded-full bg-white border border-slate-200 flex items-center justify-center text-woot-600 shadow-sm">
            <i class="i-lucide-trello text-lg" />
          </div>
          <div>
            <h2 class="text-base font-bold text-slate-800">
              {{ form.conversation_id ? $t('KANBAN.MODAL.EDIT_ITEM') : $t('KANBAN.MODAL.NEW_ITEM') }}
            </h2>
            <p class="text-xs text-slate-500 font-medium">
              {{ form.conversation_id ? `#${form.conversation_id}` : $t('KANBAN.MODAL.CREATING_CARD') }}
            </p>
          </div>
        </div>
        <button 
          @click="emit('close')"
          class="p-2 hover:bg-slate-200 rounded-lg text-slate-400 hover:text-slate-600 transition-colors"
        >
          <i class="i-lucide-x text-lg" />
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto p-6 space-y-6">
        <!-- Title -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.TITLE') }}</label>
          <input
            v-model="form.title"
            type="text"
            :placeholder="$t('KANBAN.MODAL.TITLE_PLACEHOLDER')"
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 transition-all"
          />
        </div>

        <!-- Description -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.DESCRIPTION') }}</label>
          <textarea
            v-model="form.description"
            rows="3"
            :placeholder="$t('KANBAN.MODAL.DESCRIPTION_PLACEHOLDER')"
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 transition-all resize-none"
          />
        </div>

        <!-- Notes -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.NOTES') }}</label>
          <textarea
            v-model="form.notes"
            rows="3"
            :placeholder="$t('KANBAN.MODAL.NOTES_PLACEHOLDER')"
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-600 focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 transition-all resize-none"
          />
        </div>

        <!-- Custom Attributes -->
        <div v-if="customAttributes.length > 0" class="space-y-3 pt-2 border-t border-slate-100">
          <div v-for="attr in customAttributes" :key="attr.id" class="space-y-1.5">
            <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ attr.attribute_display_name }}</label>
            
            <!-- Text / Link / Number / Date -->
            <input
              v-if="['text', 'link', 'number', 'date'].includes(attr.attribute_display_type)"
              v-model="form.custom_attributes[attr.attribute_key]"
              :type="attr.attribute_display_type === 'link' ? 'url' : attr.attribute_display_type"
              :placeholder="attr.attribute_display_name"
              class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 transition-all"
            />

            <!-- List -->
            <select
              v-else-if="attr.attribute_display_type === 'list'"
              v-model="form.custom_attributes[attr.attribute_key]"
              class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 transition-all"
            >
              <option value="">Selecione...</option>
              <option v-for="opt in attr.attribute_values" :key="opt" :value="opt">
                {{ opt }}
              </option>
            </select>

            <!-- Checkbox -->
            <label v-else-if="attr.attribute_display_type === 'checkbox'" class="flex items-center gap-2 cursor-pointer">
              <input 
                type="checkbox" 
                v-model="form.custom_attributes[attr.attribute_key]" 
                class="rounded border-slate-300 text-woot-600 focus:ring-woot-500 h-4 w-4" 
              />
              <span class="text-sm text-slate-600">{{ attr.attribute_display_name }}</span>
            </label>
          </div>
        </div>

        <!-- Stage Selection -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.STAGE') || 'Estágio' }}</label>
          <select
            v-model="form.stage_id"
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500 transition-all"
          >
            <option v-for="stage in board.stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </div>

        <!-- Value & Priority Row -->
        <div class="grid grid-cols-2 gap-6">
          <!-- Value -->
          <div class="space-y-1.5">
            <div class="flex items-center justify-between">
              <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.DEAL_VALUE') }}</label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" v-model="form.hasValue" class="rounded border-slate-300 text-woot-600 focus:ring-woot-500 h-3 w-3" />
                <span class="text-[10px] font-bold text-slate-500 uppercase">{{ $t('KANBAN.MODAL.ACTIVATE') }}</span>
              </label>
            </div>
            <div class="flex rounded-lg border border-slate-300 overflow-hidden focus-within:ring-2 focus-within:ring-woot-500/20 focus-within:border-woot-500 transition-all bg-white">
              <div class="bg-slate-50 px-3 py-2.5 border-r border-slate-200 text-slate-500 text-sm font-bold flex items-center">
                R$
              </div>
              <input
                v-model="form.value"
                type="number"
                step="0.01"
                min="0"
                placeholder="0.00"
                :disabled="!form.hasValue"
                class="flex-1 px-3 py-2.5 bg-transparent text-sm font-bold text-slate-800 focus:outline-none disabled:bg-slate-50 disabled:text-slate-400 disabled:cursor-not-allowed"
              />
            </div>
          </div>

          <!-- Priority -->
          <div class="space-y-1.5">
            <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.PRIORITY') }}</label>
            <div class="flex gap-2">
              <button
                v-for="p in ['low', 'medium', 'high', 'urgent']"
                :key="p"
                @click="form.priority = p"
                class="flex-1 py-2 rounded-lg text-xs font-bold border transition-all capitalize"
                :class="form.priority === p ? getPriorityClasses(p) : 'border-slate-200 text-slate-500 hover:bg-slate-50'"
              >
                {{ $t(`KANBAN.MODAL.PRIORITY_LABEL.${p.toUpperCase()}`) }}
              </button>
            </div>
          </div>
        </div>

        <!-- Checklist Section -->
        <div class="space-y-3 pt-4 border-t border-slate-100">
          <div class="flex items-center justify-between">
            <label class="text-xs font-bold text-slate-700 uppercase tracking-wider flex items-center gap-2">
              <i class="i-lucide-check-square text-slate-400" />
              {{ $t('KANBAN.MODAL.CHECKLIST') }}
            </label>
            <span class="text-xs font-medium text-slate-500">
              {{ checklistProgress }}
            </span>
          </div>

          <!-- Progress Bar -->
          <div class="h-1.5 w-full bg-slate-100 rounded-full overflow-hidden">
            <div 
              class="h-full bg-woot-500 transition-all duration-500 ease-out"
              :style="{ width: checklistPercentage + '%' }"
            />
          </div>

          <!-- Add Item -->
          <div class="flex gap-2">
            <input
              v-model="newChecklistItem"
              @keydown.enter.prevent="addChecklistItem"
              type="text"
              :placeholder="$t('KANBAN.MODAL.ADD_CHECKLIST_ITEM')"
              class="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-md text-sm focus:outline-none focus:border-woot-500"
            />
            <button 
              @click="addChecklistItem"
              :disabled="!newChecklistItem"
              class="px-4 py-2 bg-slate-100 text-slate-600 rounded-md text-sm font-bold hover:bg-slate-200 disabled:opacity-50"
            >
              {{ $t('KANBAN.MODAL.ADD') }}
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
                class="rounded border-slate-300 text-woot-600 focus:ring-woot-500 h-4 w-4 cursor-pointer"
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
              {{ $t('KANBAN.MODAL.NO_CHECKLIST_ITEMS') }}
            </div>
          </div>
        </div>

        <!-- Conversation Link -->
        <div class="space-y-1.5 pt-4 border-t border-slate-100">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.LINK_CONVERSATION') }}</label>
          
          <div v-if="!form.conversation_id" class="relative">
            <i class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              :placeholder="$t('KANBAN.MODAL.SEARCH_PLACEHOLDER')"
              class="w-full pl-9 pr-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
              @input="e => searchConversations(e.target.value)"
            />
            
            <!-- Search Results -->
            <div v-if="searchResults.length > 0" class="absolute z-50 w-full mt-1 bg-white border border-slate-200 rounded-lg shadow-xl max-h-60 overflow-y-auto">
              <button
                v-for="conv in searchResults"
                :key="conv.id"
                @click="selectConversation(conv)"
                class="w-full text-left px-4 py-2 hover:bg-slate-50 flex items-center justify-between group"
              >
                <div>
                  <div class="font-medium text-slate-800 text-sm">
                    #{{ conv.id }} - {{ conv.meta?.sender?.name || conv.contact?.name || 'Sem nome' }}
                  </div>
                  <div class="text-xs text-slate-500">{{ conv.messages?.[0]?.content?.substring(0, 40) }}...</div>
                </div>
                <i class="i-lucide-link text-slate-300 group-hover:text-woot-500" />
              </button>
            </div>
          </div>

          <div v-else class="flex items-center justify-between p-3 bg-woot-50 border border-woot-100 rounded-lg">
            <div class="flex items-center gap-3">
              <div class="h-8 w-8 rounded-full bg-woot-100 flex items-center justify-center text-woot-600 font-bold text-xs">
                #{{ form.conversation_id }}
              </div>
              <div>
                <div class="text-sm font-bold text-slate-800">{{ $t('KANBAN.MODAL.LINKED_CONVERSATION') }}</div>
                <div class="text-xs text-slate-500">Clique em salvar para confirmar as alterações</div>
              </div>
            </div>
            <button 
              @click="form.conversation_id = null"
              class="text-xs font-bold text-red-500 hover:text-red-600 hover:underline"
            >
              {{ $t('KANBAN.MODAL.UNLINK') }}
            </button>
          </div>
        </div>

        <!-- Agent -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold text-slate-700 uppercase tracking-wider">{{ $t('KANBAN.MODAL.ASSIGNEE') }}</label>
          <select
            v-model="form.assignee_id"
            class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-woot-500/20 focus:border-woot-500"
          >
            <option :value="null">{{ $t('KANBAN.MODAL.NO_ASSIGNEE') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </div>
      </div>

      <!-- Footer -->
      <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-between items-center gap-3">
        <div class="text-xs text-slate-400 font-mono">
          {{ form.conversation_id ? `#${form.conversation_id}` : 'Novo Item' }}
        </div>
        <div class="flex gap-3">
          <button
            @click="emit('close')"
            class="px-4 py-2 text-sm font-bold text-slate-700 bg-white border border-slate-300 hover:bg-slate-50 rounded-lg transition-colors shadow-sm"
          >
            {{ $t('KANBAN.MODAL.CANCEL') }}
          </button>
          <button
            @click="handleSave"
            :disabled="isLoading"
            class="px-6 py-2 text-sm font-bold text-white bg-green-600 hover:bg-green-700 rounded-lg shadow-sm shadow-green-200 transition-all disabled:opacity-70 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <i v-if="isLoading" class="i-lucide-loader-2 animate-spin" />
            {{ isLoading ? $t('KANBAN.MODAL.SAVING') : $t('KANBAN.MODAL.SAVE') }}
          </button>
        </div>
      </div>
    </div>
  </Modal>
</template>
