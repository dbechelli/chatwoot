<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  stageId: { type: String, default: '' },
  board: { type: Object, required: true },
});

const emit = defineEmits(['close', 'save']);
const store = useStore();
const { t } = useI18n();

const isLoading = ref(false);
const searchResults = ref([]);
const isSearching = ref(false);

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
});

// Watch stageId prop change
watch(() => props.stageId, (newVal) => {
  if (newVal) form.value.stage_id = newVal;
});

const agents = computed(() => store.getters['agents/getAgents']);
const stages = computed(() => props.board.stages || []);

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

const handleSave = async () => {
  if (!form.value.conversation_id) {
    // TODO: Handle creation without conversation (maybe create a new one?)
    // For now, we require a conversation to "link" to.
    return;
  }

  isLoading.value = true;
  try {
    const conversationId = form.value.conversation_id;
    
    // 1. Update Custom Attributes (Title, Description, Value, Stage)
    const customAttributes = {
      kanban_title: form.value.title,
      kanban_description: form.value.description,
      deal_value: form.value.hasValue ? form.value.value : 0,
      [props.board.customAttributeKey]: form.value.stage_id,
    };

    await store.dispatch('updateCustomAttributes', {
      conversationId,
      customAttributes,
    });

    // 2. Update Priority if changed
    if (form.value.priority) {
      await store.dispatch('updateConversation', {
        conversationId,
        priority: form.value.priority,
      });
    }

    // 3. Update Assignee if changed
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

const selectConversation = (conv) => {
  form.value.conversation_id = conv.id;
  // Auto-fill title if empty
  if (!form.value.title) {
    form.value.title = `Deal: ${conv.meta?.sender?.name || 'Novo Item'}`;
  }
  searchResults.value = [];
};

</script>

<template>
  <Modal :show="show" :on-close="() => emit('close')">
    <div class="flex flex-col h-full max-h-[90vh] w-full max-w-2xl bg-white rounded-xl shadow-2xl overflow-hidden">
      <!-- Header -->
      <div class="flex items-center justify-between p-6 border-b border-slate-100">
        <h2 class="text-xl font-bold text-slate-800">
          {{ $t('KANBAN.ADD_ITEM') || 'Adicionar Item' }}
        </h2>
        <button @click="emit('close')" class="text-slate-400 hover:text-slate-600">
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto p-6 space-y-5">
        
        <!-- Stage Selection -->
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Etapa</label>
          <select 
            v-model="form.stage_id"
            class="w-full rounded-lg border-slate-200 focus:border-blue-500 focus:ring-blue-500"
          >
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </div>

        <!-- Title -->
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Título</label>
          <input 
            v-model="form.title"
            type="text" 
            class="w-full rounded-lg border-slate-200 focus:border-blue-500 focus:ring-blue-500"
            placeholder="Ex: Venda Sistema Solar - Cliente X"
          />
        </div>

        <!-- Description -->
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Descrição</label>
          <textarea 
            v-model="form.description"
            rows="3"
            class="w-full rounded-lg border-slate-200 focus:border-blue-500 focus:ring-blue-500"
            placeholder="Detalhes sobre este item..."
          />
        </div>

        <!-- Value -->
        <div class="flex items-start gap-4">
          <div class="flex items-center h-10">
            <input 
              id="hasValue"
              v-model="form.hasValue"
              type="checkbox"
              class="rounded border-slate-300 text-blue-600 focus:ring-blue-500"
            />
            <label for="hasValue" class="ml-2 text-sm text-slate-700">Esse item possui um valor</label>
          </div>
          <div v-if="form.hasValue" class="flex-1">
            <div class="relative">
              <span class="absolute left-3 top-2.5 text-slate-500">R$</span>
              <input 
                v-model="form.value"
                type="number"
                class="w-full pl-10 rounded-lg border-slate-200 focus:border-blue-500 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>

        <!-- Priority -->
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Prioridade</label>
          <select 
            v-model="form.priority"
            class="w-full rounded-lg border-slate-200 focus:border-blue-500 focus:ring-blue-500"
          >
            <option value="low">Baixa</option>
            <option value="medium">Média</option>
            <option value="high">Alta</option>
            <option value="urgent">Urgente</option>
          </select>
        </div>

        <!-- Assignee -->
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Agente Responsável</label>
          <select 
            v-model="form.assignee_id"
            class="w-full rounded-lg border-slate-200 focus:border-blue-500 focus:ring-blue-500"
          >
            <option :value="null">Não atribuído</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </div>

        <!-- Conversation Link -->
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">
            Vincular à uma conversa
            <span class="text-red-500">*</span>
          </label>
          
          <div v-if="!form.conversation_id" class="relative">
            <input 
              type="text"
              class="w-full rounded-lg border-slate-200 focus:border-blue-500 focus:ring-blue-500"
              placeholder="Buscar conversa (nome, email, id)..."
              @input="e => searchConversations(e.target.value)"
            />
            <div v-if="searchResults.length > 0" class="absolute z-10 w-full mt-1 bg-white border border-slate-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
              <div 
                v-for="result in searchResults" 
                :key="result.id"
                class="p-3 hover:bg-slate-50 cursor-pointer border-b border-slate-100 last:border-0"
                @click="selectConversation(result)"
              >
                <div class="flex items-center gap-2">
                  <span class="font-bold text-slate-700">#{{ result.id }}</span>
                  <span class="text-slate-600">{{ result.meta?.sender?.name }}</span>
                </div>
                <p class="text-xs text-slate-400 truncate">{{ result.messages?.[0]?.content }}</p>
              </div>
            </div>
          </div>

          <div v-else class="flex items-center justify-between p-3 bg-blue-50 border border-blue-100 rounded-lg">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 bg-blue-200 rounded-full flex items-center justify-center text-blue-700 font-bold">
                #{{ form.conversation_id }}
              </div>
              <span class="text-sm font-medium text-blue-900">Conversa Selecionada</span>
            </div>
            <button @click="form.conversation_id = null" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
              Alterar
            </button>
          </div>
        </div>

      </div>

      <!-- Footer -->
      <div class="p-6 border-t border-slate-100 bg-slate-50 flex justify-end gap-3">
        <button 
          @click="emit('close')"
          class="px-4 py-2 text-slate-600 hover:bg-slate-200 rounded-lg transition-colors"
        >
          Cancelar
        </button>
        <button 
          @click="handleSave"
          :disabled="isLoading || !form.conversation_id"
          class="px-6 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          <i v-if="isLoading" class="i-lucide-loader-2 animate-spin" />
          Salvar
        </button>
      </div>
    </div>
  </Modal>
</template>
