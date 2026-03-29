<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import { uploadFile } from 'dashboard/helper/uploadHelper';

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
  start_date: '',
  due_date: '',
  scheduled_message: '',
  scheduled_at: '',
});



const agents = computed(() => store.getters['agents/getAgents']);
const allLabels = computed(() => store.getters['labels/getLabels']);

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
      start_date: newItem.custom_attributes?.kanban_start_date || '',
      due_date: newItem.custom_attributes?.kanban_due_date || '',
      scheduled_message: newItem.custom_attributes?.kanban_scheduled_message || '',
      scheduled_at: newItem.custom_attributes?.kanban_scheduled_at || '',
      labels: newItem.labels || newItem.conversation_labels || [],
      attachments: newItem.custom_attributes?.kanban_attachments || [],
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
      scheduled_message: '',
      scheduled_at: '',
      start_date: '',
      due_date: '',
      labels: [],
      attachments: [],
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

  // Dates
  form.value.start_date = attrs.kanban_start_date || '';
  form.value.due_date = attrs.kanban_due_date || '';
  
  // Scheduled Message
  form.value.scheduled_message = attrs.kanban_scheduled_message || '';
  form.value.scheduled_at = attrs.kanban_scheduled_at || '';

  // Labels
  form.value.labels = conv.labels || [];
  
  // Attachments
  form.value.attachments = attrs.kanban_attachments || [];

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
    low: 'border-n-weak bg-n-slate-2 text-n-slate-11',
    medium: 'border-n-brand/20 bg-n-brand/10 text-n-blue-11',
    high: 'border-n-amber-6/40 bg-n-amber-3 text-n-amber-11',
    urgent: 'border-n-ruby-6/40 bg-n-ruby-3 text-n-ruby-11',
  };
  return map[p];
};

const wonStage = computed(() => {
  if (!props.board?.stages) return null;
  return props.board.stages.find(s => ['won', 'ganho', 'concluido', 'concluído', 'fechado', 'venda', 'sucesso'].some(k => s.name.toLowerCase().includes(k)));
});

const lostStage = computed(() => {
  if (!props.board?.stages) return null;
  return props.board.stages.find(s => ['lost', 'perda', 'perdido', 'cancelado', 'arquivado'].some(k => s.name.toLowerCase().includes(k)));
});

const moveToStage = async (stageId) => {
  form.value.stage_id = stageId;
  await handleSave();
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
      kanban_start_date: form.value.start_date || null,
      kanban_due_date: form.value.due_date || null,
      kanban_scheduled_message: form.value.scheduled_message || null,
      kanban_scheduled_at: form.value.scheduled_at || null,
      kanban_attachments: form.value.attachments,
      [boardCustomAttributeKey.value]: form.value.stage_id,
      ...form.value.custom_attributes,
    };

    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes,
    });
    
    // 4. Update Labels
    if (form.value.labels) {
       await store.dispatch('conversationLabels/update', {
         conversationId,
         labels: form.value.labels
       });
    }

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

const fileInputRef = ref(null);
const isUploading = ref(false);

const triggerFileUpload = () => {
  fileInputRef.value.click();
};

const handleAttachmentUpload = async (event) => {
  const file = event.target.files[0];
  if (!file) return;

  isUploading.value = true;
  try {
    const { fileUrl, blobId } = await uploadFile(file, store.getters.getCurrentAccountId);
    
    // Store object with metadata
    form.value.attachments.push({
      id: blobId,
      url: fileUrl,
      name: file.name,
      type: file.type
    });
  } catch (error) {
    useAlert(t('KANBAN.MODAL.UPLOAD_ERROR') || 'Erro ao fazer upload');
  } finally {
    isUploading.value = false;
    event.target.value = ''; // Reset input
  }
};

const removeAttachment = (index) => {
  form.value.attachments.splice(index, 1);
};
const openAttachment = (url) => {
  window.open(url, '_blank');
};


</script>

<template>
  <Modal :show="show" :on-close="() => emit('close')" size="lg" :show-close-button="false">
    <div class="flex h-full max-h-[85vh] flex-col overflow-hidden rounded-2xl bg-n-surface-1">
      <div class="flex items-center justify-between border-b border-n-weak bg-n-slate-2/60 px-6 py-4">
        <div class="flex items-center gap-3">
          <div class="flex h-8 w-8 items-center justify-center rounded-full border border-n-weak bg-n-surface-1 text-n-blue-11">
            <i class="i-lucide-trello text-lg" />
          </div>
          <div>
            <h2 class="text-base font-medium text-n-slate-12">
              {{ form.conversation_id ? $t('KANBAN.MODAL.EDIT_ITEM') : $t('KANBAN.MODAL.NEW_ITEM') }}
            </h2>
            <p class="text-xs font-medium text-n-slate-10">
              {{ form.conversation_id ? `#${form.conversation_id}` : $t('KANBAN.MODAL.CREATING_CARD') }}
            </p>
          </div>
        </div>
        <button 
          @click="emit('close')"
          class="rounded-lg p-2 text-n-slate-10 transition-colors hover:bg-n-slate-3 hover:text-n-slate-12"
        >
          <i class="i-lucide-x text-lg" />
        </button>
      </div>

      <div class="flex-1 space-y-6 overflow-y-auto p-6">
        <div class="space-y-1.5">
          <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.TITLE') }}</label>
          <input
            v-model="form.title"
            type="text"
            :placeholder="$t('KANBAN.MODAL.TITLE_PLACEHOLDER')"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm font-medium text-n-slate-12 outline-none transition focus:border-n-brand"
          />
        </div>

        <div class="space-y-1.5">
          <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.DESCRIPTION') }}</label>
          <textarea
            v-model="form.description"
            rows="3"
            :placeholder="$t('KANBAN.MODAL.DESCRIPTION_PLACEHOLDER')"
            class="w-full resize-none rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-11 outline-none transition focus:border-n-brand"
          />
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="space-y-1.5">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.ASSIGNEE') }}</label>
            <select
              v-model="form.assignee_id"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            >
              <option :value="null">{{ $t('KANBAN.MODAL.NO_ASSIGNEE') }}</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </div>
          
           <div class="space-y-1.5">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">Etiquetas</label>
            <TagMultiSelectComboBox
              v-model="form.labels"
              :options="allLabels"
              placeholder="Selecionar etiquetas"
              search-placeholder="Buscar etiqueta"
            />
          </div>
        </div>

        <div class="space-y-1.5">
          <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.NOTES') }}</label>
          <textarea
            v-model="form.notes"
            rows="3"
            :placeholder="$t('KANBAN.MODAL.NOTES_PLACEHOLDER')"
            class="w-full resize-none rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-11 outline-none transition focus:border-n-brand"
          />
        </div>

        <div v-if="customAttributes.length > 0" class="space-y-3 border-t border-n-weak pt-2">
          <div v-for="attr in customAttributes" :key="attr.id" class="space-y-1.5">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ attr.attribute_display_name }}</label>
            
            <input
              v-if="['text', 'link', 'number', 'date'].includes(attr.attribute_display_type)"
              v-model="form.custom_attributes[attr.attribute_key]"
              :type="attr.attribute_display_type === 'link' ? 'url' : attr.attribute_display_type"
              :placeholder="attr.attribute_display_name"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            />

            <select
              v-else-if="attr.attribute_display_type === 'list'"
              v-model="form.custom_attributes[attr.attribute_key]"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            >
              <option value="">Selecione...</option>
              <option v-for="opt in attr.attribute_values" :key="opt" :value="opt">
                {{ opt }}
              </option>
            </select>

            <label v-else-if="attr.attribute_display_type === 'checkbox'" class="flex cursor-pointer items-center gap-2">
              <input 
                type="checkbox" 
                v-model="form.custom_attributes[attr.attribute_key]" 
                class="h-4 w-4 rounded border-n-strong text-n-brand focus:ring-n-brand" 
              />
              <span class="text-sm text-n-slate-11">{{ attr.attribute_display_name }}</span>
            </label>
          </div>
        </div>

        <div class="space-y-3 border-t border-n-weak pt-4">
           <label class="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-n-slate-10">
            <i class="i-lucide-paperclip text-n-slate-10" />
            Anexar Arquivos
          </label>
          <div class="space-y-2">
             <input type="file" ref="fileInputRef" @change="handleAttachmentUpload" class="hidden" />
             <button 
               @click="triggerFileUpload" 
               class="flex w-full items-center justify-center gap-2 rounded-xl border border-dashed border-n-weak bg-n-slate-2 px-3 py-2 text-sm text-n-slate-11 transition-colors hover:bg-n-slate-3"
               :disabled="isUploading"
             >
               <i v-if="isUploading" class="i-lucide-loader-2 animate-spin" />
               <i v-else class="i-lucide-upload-cloud" />
               {{ isUploading ? 'Enviando...' : 'Clique para enviar arquivo' }}
             </button>

             <div v-if="form.attachments.length > 0" class="mt-2 space-y-2">
                <div v-for="(att, idx) in form.attachments" :key="idx" class="group flex items-center gap-3 rounded-xl border border-n-weak bg-n-slate-2/60 p-2">
                   <div 
                     class="flex h-10 w-10 shrink-0 cursor-pointer items-center justify-center overflow-hidden rounded-lg bg-n-slate-3"
                     @click="att.url ? openAttachment(att.url) : null"
                   >
                     <img v-if="att.url && (att.type?.startsWith('image') || att.url?.match(/\.(jpeg|jpg|gif|png)$/i))" :src="att.url" class="h-full w-full object-cover" />
                     <i v-else class="i-lucide-file-text text-n-slate-10" />
                   </div>

                   <div class="flex-1 min-w-0" @click="att.url ? openAttachment(att.url) : null">
                     <div class="cursor-pointer truncate text-xs font-medium text-n-slate-12 hover:underline">
                       {{ att.name || (typeof att === 'object' ? `Anexo #${att.id}` : `Anexo (Legado)`) }}
                     </div>
                     <div class="truncate text-[10px] text-n-slate-10" v-if="att.id">ID: {{ att.id }}</div>
                   </div>

                   <button @click="removeAttachment(idx)" class="rounded p-1.5 text-n-slate-10 transition-colors hover:bg-n-ruby-3 hover:text-n-ruby-11">
                     <i class="i-lucide-trash-2 text-xs" />
                   </button>
                </div>
             </div>
          </div>
        </div>

        <div class="border-t border-n-weak pt-4">
           <button class="flex items-center gap-2 text-sm font-medium text-n-slate-11 hover:text-n-slate-12">
             <i class="i-lucide-history" />
             Ver Histórico da Tarefa (Em breve)
           </button>
        </div>

        <div class="space-y-1.5">
          <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.STAGE') || 'Estágio' }}</label>
          <select
            v-model="form.stage_id"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
          >
            <option v-for="stage in board.stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </div>

        <div class="grid grid-cols-2 gap-6">
          <div class="space-y-1.5">
            <div class="flex items-center justify-between">
              <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.DEAL_VALUE') }}</label>
              <label class="flex cursor-pointer items-center gap-2">
                <input type="checkbox" v-model="form.hasValue" class="h-3 w-3 rounded border-n-strong text-n-brand focus:ring-n-brand" />
                <span class="text-[10px] font-medium uppercase text-n-slate-10">{{ $t('KANBAN.MODAL.ACTIVATE') }}</span>
              </label>
            </div>
            <div class="flex overflow-hidden rounded-xl border border-n-weak bg-n-surface-1 transition focus-within:border-n-brand">
              <div class="flex items-center border-r border-n-weak bg-n-slate-2 px-3 py-2.5 text-sm font-medium text-n-slate-10">
                R$
              </div>
              <input
                v-model="form.value"
                type="number"
                step="0.01"
                min="0"
                placeholder="0.00"
                :disabled="!form.hasValue"
                class="flex-1 bg-transparent px-3 py-2.5 text-sm font-medium text-n-slate-12 outline-none disabled:bg-n-slate-2 disabled:text-n-slate-10 disabled:cursor-not-allowed"
              />
            </div>
          </div>

          <div class="space-y-1.5">
            <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.PRIORITY') }}</label>
            <div class="flex gap-2">
              <button
                v-for="p in ['low', 'medium', 'high', 'urgent']"
                :key="p"
                @click="form.priority = p"
                class="flex-1 rounded-lg border py-2 text-xs font-medium capitalize transition-all"
                :class="form.priority === p ? getPriorityClasses(p) : 'border-n-weak text-n-slate-11 hover:bg-n-slate-2'"
              >
                {{ $t(`KANBAN.MODAL.PRIORITY_LABEL.${p.toUpperCase()}`) }}
              </button>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-6 pt-2">
          <div class="space-y-1.5">
            <label class="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-n-slate-10">
              <i class="i-lucide-calendar-clock text-n-slate-10" />
              {{ $t('KANBAN.MODAL.START_DATE') }}
            </label>
            <input
              v-model="form.start_date"
              type="date"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            />
          </div>

          <div class="space-y-1.5">
            <label class="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-n-slate-10">
              <i class="i-lucide-calendar-x text-n-slate-10" />
              {{ $t('KANBAN.MODAL.DUE_DATE') }}
            </label>
            <input
              v-model="form.due_date"
              type="date"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            />
          </div>
        </div>

        <div class="space-y-3 border-t border-n-weak pt-4">
           <label class="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-n-slate-10">
            <i class="i-lucide-message-square-clock text-n-slate-10" />
            Agendar Mensagem Automática
          </label>
          <div class="grid grid-cols-1 gap-4">
            <div class="space-y-1.5">
               <textarea
                v-model="form.scheduled_message"
                rows="2"
                placeholder="Digite a mensagem para enviar automaticamente..."
                class="w-full resize-none rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-11 outline-none transition focus:border-n-brand"
              />
            </div>
             <div class="space-y-1.5">
               <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">Data e Hora do Envio</label>
               <input
                v-model="form.scheduled_at"
                type="datetime-local"
                class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
              />
            </div>
          </div>
        </div>

        <div class="space-y-3 border-t border-n-weak pt-4">
          <div class="flex items-center justify-between">
            <label class="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-n-slate-10">
              <i class="i-lucide-check-square text-n-slate-10" />
              {{ $t('KANBAN.MODAL.CHECKLIST') }}
            </label>
            <span class="text-xs font-medium text-n-slate-10">
              {{ checklistProgress }}
            </span>
          </div>

          <div class="h-1.5 w-full overflow-hidden rounded-full bg-n-slate-3">
            <div 
              class="h-full bg-n-brand transition-all duration-500 ease-out"
              :style="{ width: checklistPercentage + '%' }"
            />
          </div>

          <div class="flex gap-2">
            <input
              v-model="newChecklistItem"
              @keydown.enter.prevent="addChecklistItem"
              type="text"
              :placeholder="$t('KANBAN.MODAL.ADD_CHECKLIST_ITEM')"
              class="flex-1 rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
            />
            <Button @click="addChecklistItem" :disabled="!newChecklistItem" slate faded :label="$t('KANBAN.MODAL.ADD')" />
          </div>

          <div class="space-y-1">
            <div 
              v-for="(item, index) in form.checklist" 
              :key="index"
              class="group flex items-center gap-3 rounded-xl p-2 transition-colors hover:bg-n-slate-2/60"
            >
              <input 
                type="checkbox" 
                v-model="item.done"
                class="h-4 w-4 cursor-pointer rounded border-n-strong text-n-brand focus:ring-n-brand"
              />
              <input
                v-model="item.text"
                class="flex-1 border-none bg-transparent p-0 text-sm text-n-slate-12 focus:ring-0"
                :class="{ 'line-through text-n-slate-10': item.done }"
              />
              <button 
                @click="removeChecklistItem(index)"
                class="p-1 text-n-slate-10 opacity-0 transition-all group-hover:opacity-100 hover:text-n-ruby-11"
              >
                <i class="i-lucide-trash-2 text-xs" />
              </button>
            </div>
            <div v-if="form.checklist.length === 0" class="py-4 text-center text-sm italic text-n-slate-10">
              {{ $t('KANBAN.MODAL.NO_CHECKLIST_ITEMS') }}
            </div>
          </div>
        </div>

        <div class="space-y-1.5 border-t border-n-weak pt-4">
          <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.LINK_CONVERSATION') }}</label>
          
          <div v-if="!form.conversation_id" class="relative">
            <i class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 text-n-slate-10" />
            <input
              type="text"
              :placeholder="$t('KANBAN.MODAL.SEARCH_PLACEHOLDER')"
              class="w-full rounded-xl border border-n-weak bg-n-surface-1 py-2.5 pl-9 pr-3 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
              @input="e => searchConversations(e.target.value)"
            />
            
            <div v-if="searchResults.length > 0" class="absolute z-50 mt-1 max-h-60 w-full overflow-y-auto rounded-xl border border-n-weak bg-n-surface-1 shadow-xl">
              <button
                v-for="conv in searchResults"
                :key="conv.id"
                @click="selectConversation(conv)"
                class="group flex w-full items-center justify-between px-4 py-2 text-left hover:bg-n-slate-2"
              >
                <div>
                  <div class="text-sm font-medium text-n-slate-12">
                    #{{ conv.id }} - {{ conv.meta?.sender?.name || conv.contact?.name || 'Sem nome' }}
                  </div>
                  <div class="text-xs text-n-slate-10">{{ conv.messages?.[0]?.content?.substring(0, 40) }}...</div>
                </div>
                <i class="i-lucide-link text-n-slate-9 group-hover:text-n-blue-11" />
              </button>
            </div>
          </div>

          <div v-else class="flex items-center justify-between rounded-xl border border-n-brand/20 bg-n-brand/5 p-3">
            <div class="flex items-center gap-3">
              <div class="flex h-8 w-8 items-center justify-center rounded-full bg-n-brand/10 text-xs font-medium text-n-blue-11">
                #{{ form.conversation_id }}
              </div>
              <div>
                <div class="text-sm font-medium text-n-slate-12">{{ $t('KANBAN.MODAL.LINKED_CONVERSATION') }}</div>
                <div class="text-xs text-n-slate-10">Clique em salvar para confirmar as alterações</div>
              </div>
            </div>
            <button 
              @click="form.conversation_id = null"
              class="text-xs font-medium text-n-ruby-11 hover:underline"
            >
              {{ $t('KANBAN.MODAL.UNLINK') }}
            </button>
          </div>
        </div>

        <div class="space-y-1.5">
          <label class="text-xs font-medium uppercase tracking-wide text-n-slate-10">{{ $t('KANBAN.MODAL.ASSIGNEE') }}</label>
          <select
            v-model="form.assignee_id"
            class="w-full rounded-xl border border-n-weak bg-n-surface-1 px-3 py-2.5 text-sm text-n-slate-12 outline-none transition focus:border-n-brand"
          >
            <option :value="null">{{ $t('KANBAN.MODAL.NO_ASSIGNEE') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </div>
      </div>

      <div class="flex items-center justify-between gap-3 border-t border-n-weak bg-n-slate-2/60 px-6 py-4">
        <div class="flex items-center gap-2">
          <Button
            v-if="wonStage && form.stage_id !== wonStage.id"
            @click="moveToStage(wonStage.id)"
            teal
            faded
            icon="i-lucide-trophy"
            :label="'Ganho'"
            :title="wonStage.name"
          />
          <Button
            v-if="lostStage && form.stage_id !== lostStage.id"
            @click="moveToStage(lostStage.id)"
            ruby
            faded
            icon="i-lucide-thumbs-down"
            :label="'Perdido'"
            :title="lostStage.name"
          />
        </div>
        <div class="flex gap-3">
          <Button @click="emit('close')" slate outline :label="$t('KANBAN.MODAL.CANCEL')" />
          <Button
            @click="handleSave"
            :disabled="isLoading"
            blue
            solid
            :is-loading="isLoading"
            :label="isLoading ? $t('KANBAN.MODAL.SAVING') : $t('KANBAN.MODAL.SAVE')"
          />
        </div>
      </div>
    </div>
  </Modal>
</template>
