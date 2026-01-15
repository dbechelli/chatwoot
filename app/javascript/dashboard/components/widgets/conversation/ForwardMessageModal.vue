<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Avatar from 'next/avatar/Avatar.vue';
import ContactAPI from 'dashboard/api/contacts';
import { debounce } from '@chatwoot/utils';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  conversationId: {
    type: Number,
    required: true,
  },
  messageId: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['close', 'forward']);

const store = useStore();
const { t } = useI18n();

const searchQuery = ref('');
const selectedContacts = ref([]);
const isForwarding = ref(false);
const isSearching = ref(false);
const includeAttachments = ref(true);
const searchResults = ref([]);

const conversation = computed(() =>
  store.getters.getConversationById(props.conversationId)
);

const allContacts = computed(() => store.getters['contacts/getContacts'] || []);

const contactsList = computed(() => {
  if (isSearching.value) return [];
  if (searchQuery.value) return searchResults.value;
  return allContacts.value.slice(0, 50);
});

const isContactSelected = contactId => {
  return selectedContacts.value.includes(contactId);
};

const toggleContact = contactId => {
  const index = selectedContacts.value.indexOf(contactId);
  if (index > -1) {
    selectedContacts.value.splice(index, 1);
  } else {
    selectedContacts.value.push(contactId);
  }
};

const canForward = computed(() => {
  return selectedContacts.value.length > 0 && !isForwarding.value;
});

const closeModal = () => {
  searchQuery.value = '';
  selectedContacts.value = [];
  includeAttachments.value = true;
  searchResults.value = [];
  emit('close');
};

const performSearch = debounce(async (query) => {
  if (!query) {
    searchResults.value = [];
    isSearching.value = false;
    return;
  }
  
  isSearching.value = true;
  try {
    const { data } = await ContactAPI.search(query);
    searchResults.value = data.payload;
  } catch (error) {
    console.error(error);
  } finally {
    isSearching.value = false;
  }
}, 300);

watch(searchQuery, (newQuery) => {
  if (!newQuery) {
    searchResults.value = [];
    return;
  }
  isSearching.value = true; // Set loading immediately
  performSearch(newQuery);
});

const forwardToContacts = async () => {
  if (!canForward.value) return;

  isForwarding.value = true;

  try {
    // Get the message to forward
    const messageIdToForward =
      props.messageId ||
      conversation.value?.messages?.[conversation.value.messages.length - 1]
        ?.id;

    if (!messageIdToForward) {
      useAlert(t('FORWARD_MESSAGE.NO_MESSAGES'));
      isForwarding.value = false;
      return;
    }

    // Call the forward API endpoint
    const response = await store.dispatch('forwardMessage', {
      conversationId: props.conversationId,
      messageId: messageIdToForward,
      contactIds: selectedContacts.value,
    });

    // Process results
    const results = response?.results || [];
    const successCount = results.filter(r => r.success).length;
    const errorCount = results.filter(r => !r.success).length;

    // Show result
    if (successCount > 0) {
      useAlert(
        t('CONVERSATION.FORWARD_MESSAGE.SUCCESS', { count: successCount })
      );
    }

    if (errorCount > 0) {
      const failureCount = errorCount;
      if (successCount === 0) {
        useAlert(t('CONVERSATION.FORWARD_MESSAGE.ERROR'));
      } else {
        useAlert(
          t('CONVERSATION.FORWARD_MESSAGE.PARTIAL_ERROR', {
            count: failureCount,
          })
        );
      }
    }

    emit('forward', {
      contactIds: selectedContacts.value,
      success: successCount,
      errors: errorCount,
    });

    closeModal();
  } catch (error) {
    console.error('Error forwarding message:', error);
    const errorMessage = error.response?.data?.error || error.message || t('CONVERSATION.FORWARD_MESSAGE.ERROR');
    useAlert(errorMessage);
  } finally {
    isForwarding.value = false;
  }
};

onMounted(() => {
  // Carregar contatos se necessário
  if (allContacts.value.length === 0) {
    store.dispatch('contacts/get');
  }
});
</script>

<template>
  <Modal :show="show" :on-close="closeModal" :show-close-button="false">
    <div class="flex flex-col h-full max-h-[80vh] w-full">
      <!-- Header -->
      <div class="flex items-center justify-between p-6 border-b border-n-weak bg-white">
        <div class="flex-1">
          <h2 class="text-xl font-semibold text-n-slate-12">
            {{ $t('FORWARD_MESSAGE.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ $t('FORWARD_MESSAGE.DESCRIPTION') }}
          </p>
        </div>
        <button
          class="p-2 rounded-lg hover:bg-n-slate-3 transition-colors flex items-center justify-center text-n-slate-10 hover:text-n-slate-12 ml-4"
          @click="closeModal"
        >
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <!-- Busca -->
      <div class="p-4 border-b border-n-weak bg-white">
        <div class="relative flex items-center">
          <i
            class="i-lucide-search absolute left-3 text-n-slate-11 text-lg"
            :class="{ 'animate-pulse text-n-brand': isSearching }"
          />
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="$t('FORWARD_MESSAGE.SEARCH_PLACEHOLDER')"
            class="w-full pl-10 pr-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent transition-all"
          />
        </div>
      </div>

      <!-- Contatos selecionados (tags) -->
      <div
        v-if="selectedContacts.length > 0"
        class="flex flex-wrap gap-2 p-4 border-b border-n-weak bg-n-slate-1 max-h-[120px] overflow-y-auto"
      >
        <div
          v-for="contactId in selectedContacts"
          :key="contactId"
          class="inline-flex items-center gap-2 px-3 py-1.5 bg-n-brand text-white rounded-full text-sm font-medium shadow-sm"
        >
          <span>
            {{
              contactsList.find(c => c.id === contactId)?.name ||
              allContacts.find(c => c.id === contactId)?.name ||
              $t('FORWARD_MESSAGE.UNKNOWN_CONTACT')
            }}
          </span>
          <button
            class="hover:bg-white/20 rounded-full p-0.5 transition-colors"
            @click="toggleContact(contactId)"
          >
            <i class="i-lucide-x text-sm" />
          </button>
        </div>
      </div>

      <!-- Lista de contatos -->
      <div class="flex-1 overflow-y-auto p-4 bg-n-slate-1 min-h-[350px]">
        <!-- Loading state -->
        <div
          v-if="isSearching && searchQuery"
          class="flex flex-col items-center justify-center py-16 text-center"
        >
          <i class="i-lucide-loader-2 animate-spin text-4xl text-n-brand mb-3" />
          <p class="text-n-slate-11 font-medium">
            {{ $t('FORWARD_MESSAGE.SEARCHING') || 'Buscando contatos...' }}
          </p>
        </div>

        <!-- Empty state -->
        <div
          v-else-if="contactsList.length === 0"
          class="flex flex-col items-center justify-center py-16 text-center"
        >
          <i class="i-lucide-users text-5xl text-n-slate-10 mb-4" />
          <p class="text-n-slate-11 font-medium text-lg">
            {{
              searchQuery
                ? $t('FORWARD_MESSAGE.NO_CONTACTS_FOUND')
                : $t('FORWARD_MESSAGE.NO_CONTACTS')
            }}
          </p>
          <p v-if="searchQuery" class="text-n-slate-10 text-sm mt-2">
            Tente uma busca diferente
          </p>
        </div>

        <!-- Contact list -->
        <div v-else class="space-y-1">
          <button
            v-for="contact in contactsList"
            :key="contact.id"
            class="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-white transition-all border border-transparent hover:border-n-weak hover:shadow-sm"
            :class="{
              'bg-white border-n-brand/30 shadow-sm': isContactSelected(
                contact.id
              ),
            }"
            @click="toggleContact(contact.id)"
          >
            <!-- Checkbox -->
            <div
              class="flex-shrink-0 w-5 h-5 rounded border-2 flex items-center justify-center transition-all duration-200"
              :class="
                isContactSelected(contact.id)
                  ? 'bg-n-brand border-n-brand'
                  : 'border-n-slate-6 bg-white'
              "
            >
              <i
                v-if="isContactSelected(contact.id)"
                class="i-lucide-check text-white text-sm font-bold"
              />
            </div>

            <!-- Avatar -->
            <Avatar
              :username="contact.name"
              :src="contact.thumbnail"
              :size="40"
              class="flex-shrink-0"
            />

            <!-- Informações -->
            <div class="flex-1 text-left min-w-0">
              <p class="font-medium text-sm text-n-slate-12 truncate">
                {{ contact.name || $t('FORWARD_MESSAGE.UNKNOWN_CONTACT') }}
              </p>
              <p class="text-xs text-n-slate-11 truncate mt-0.5">
                {{ contact.email || contact.phone_number || '-' }}
              </p>
            </div>

            <!-- Badge de última interação -->
            <div
              v-if="contact.last_activity_at"
              class="text-[10px] text-n-slate-10 whitespace-nowrap bg-n-slate-2 px-2 py-1 rounded"
            >
              {{
                new Date(contact.last_activity_at * 1000).toLocaleDateString(
                  'pt-BR'
                )
              }}
            </div>
          </button>
        </div>
      </div>

      <!-- Footer com opções e botões -->
      <div class="border-t border-n-weak bg-white">
        <!-- Opção de anexos -->
        <div class="p-4 border-b border-n-weak">
          <label class="flex items-center gap-3 cursor-pointer select-none">
            <input
              v-model="includeAttachments"
              type="checkbox"
              class="w-5 h-5 rounded border-n-slate-6 text-n-brand focus:ring-n-brand"
            />
            <div class="flex-1">
              <span class="text-sm font-medium text-n-slate-12 block">
                {{ $t('FORWARD_MESSAGE.INCLUDE_ATTACHMENTS') }}
              </span>
              <span class="text-xs text-n-slate-10">
                Incluir imagens, vídeos e arquivos anexados
              </span>
            </div>
          </label>
        </div>

        <!-- Botões de ação -->
        <div class="flex items-center justify-between p-4">
          <div class="text-sm text-n-slate-11">
            <span v-if="selectedContacts.length > 0" class="font-medium">
              {{ selectedContacts.length }}
              {{
                selectedContacts.length === 1
                  ? 'contato selecionado'
                  : 'contatos selecionados'
              }}
            </span>
            <span v-else class="text-n-slate-10">
              {{ $t('FORWARD_MESSAGE.NO_SELECTION') || 'Nenhum contato selecionado' }}
            </span>
          </div>
          <div class="flex items-center gap-3">
            <button
              class="px-5 py-2.5 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-slate-2 hover:text-n-slate-12 transition-colors"
              @click="closeModal"
            >
              {{ $t('FORWARD_MESSAGE.CANCEL') }}
            </button>
            <button
              class="px-6 py-2.5 rounded-lg bg-n-brand text-white text-sm font-bold shadow-sm hover:bg-n-brand/90 hover:shadow-md transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-sm flex items-center gap-2 min-w-[140px] justify-center"
              :disabled="!canForward"
              @click="forwardToContacts"
            >
              <i
                v-if="isForwarding"
                class="i-lucide-loader-2 animate-spin text-base"
              />
              <i v-else class="i-lucide-send text-base" />
              <span>{{ $t('FORWARD_MESSAGE.FORWARD') }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>
