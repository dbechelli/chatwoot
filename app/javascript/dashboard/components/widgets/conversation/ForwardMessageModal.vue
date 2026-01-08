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
    useAlert(t('CONVERSATION.FORWARD_MESSAGE.ERROR'));
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
    <div class="flex flex-col h-full max-h-[80vh]">
      <!-- Header -->
      <div class="flex items-center justify-between p-4 border-b border-n-weak">
        <div>
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{ t('FORWARD_MESSAGE.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ t('FORWARD_MESSAGE.DESCRIPTION') }}
          </p>
        </div>
        <button
          class="p-2 rounded-lg hover:bg-n-slate-3 transition-colors flex items-center justify-center text-n-slate-10 hover:text-n-slate-12"
          @click="closeModal"
        >
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <!-- Contatos selecionados (tags) -->
      <div
        v-if="selectedContacts.length > 0"
        class="flex flex-wrap gap-2 p-4 border-b border-n-weak bg-n-slate-2 max-h-[100px] overflow-y-auto"
      >
        <div
          v-for="contactId in selectedContacts"
          :key="contactId"
          class="inline-flex items-center gap-2 px-3 py-1.5 bg-n-brand/10 text-n-brand rounded-full text-sm"
        >
          <span>
            {{
              contactsList.find(c => c.id === contactId)?.name ||
              allContacts.find(c => c.id === contactId)?.name ||
              'Contato'
            }}
          </span>
          <button
            class="hover:bg-n-brand/20 rounded-full p-0.5"
            @click="toggleContact(contactId)"
          >
            <i class="i-lucide-x text-sm" />
          </button>
        </div>
        <div class="text-xs font-medium text-n-slate-11 flex items-center bg-white px-2 rounded border border-n-weak">
          {{
            t('FORWARD_MESSAGE.SELECTED_COUNT', {
              count: selectedContacts.length,
            })
          }}
        </div>
      </div>

      <!-- Busca -->
      <div class="p-4 border-b border-n-weak">
        <div class="relative flex items-center">
          <i
            class="i-lucide-search absolute left-3 text-n-slate-11"
            :class="{ 'animate-pulse text-n-brand': isSearching }"
          />
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="t('FORWARD_MESSAGE.SEARCH_PLACEHOLDER')"
            class="w-full pl-10 pr-4 py-2 rounded-lg border border-n-weak bg-n-slate-1 text-n-slate-12 placeholder-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand transition-all"
          />
          <span v-if="isSearching" class="absolute right-3 text-xs text-n-slate-10">Searching...</span>
        </div>
      </div>

      <!-- Lista de contatos -->
      <div class="flex-1 overflow-y-auto p-4 min-h-[300px]">
        <div
          v-if="isSearching && contactsList.length === 0"
          class="flex flex-col items-center justify-center py-12 text-center"
        >
           <i class="i-lucide-loader-2 animate-spin text-3xl text-n-brand mb-2" />
           <p class="text-n-slate-11">{{ t('Pending...') || 'Searching contacts...' }}</p>
        </div>

        <div
          v-else-if="contactsList.length === 0"
          class="flex flex-col items-center justify-center py-12 text-center"
        >
          <i class="i-lucide-users text-4xl text-n-slate-11 mb-4" />
          <p class="text-n-slate-11">
            {{ searchQuery ? t('FORWARD_MESSAGE.NO_CONTACTS_FOUND') : t('FORWARD_MESSAGE.NO_CONTACTS') }}
          </p>
        </div>

        <div v-else class="space-y-1">
          <button
            v-for="contact in contactsList"
            :key="contact.id"
            class="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-n-slate-2 transition-colors border border-transparent"
            :class="{
              'bg-n-brand/5 border-n-brand/20': isContactSelected(contact.id),
            }"
            @click="toggleContact(contact.id)"
          >
            <!-- Checkbox -->
            <div
              class="flex-shrink-0 w-5 h-5 rounded border flex items-center justify-center transition-all duration-200"
              :class="
                isContactSelected(contact.id)
                  ? 'bg-n-brand border-n-brand'
                  : 'border-n-slate-6 bg-white'
              "
            >
              <i
                v-if="isContactSelected(contact.id)"
                class="i-lucide-check text-white text-xs font-bold"
              />
            </div>

            <!-- Avatar -->
            <Avatar
              :username="contact.name"
              :src="contact.thumbnail"
              :size="32"
              class="flex-shrink-0"
            />

            <!-- Informações -->
            <div class="flex-1 text-left min-w-0">
              <p class="font-medium text-sm text-n-slate-12 truncate">
                {{ contact.name || t('FORWARD_MESSAGE.UNKNOWN_CONTACT') }}
              </p>
              <p class="text-xs text-n-slate-11 truncate">
                {{ contact.email || contact.phone_number || '-' }}
              </p>
            </div>

            <!-- Badge de última interação -->
            <div
              v-if="contact.last_activity_at"
              class="text-[10px] text-n-slate-10 whitespace-nowrap"
            >
              {{
                new Date(contact.last_activity_at * 1000).toLocaleDateString()
              }}
            </div>
          </button>
        </div>
      </div>

      <!-- Opções -->
      <div class="p-4 border-t border-n-weak bg-n-slate-1">
        <label class="flex items-center gap-2 cursor-pointer select-none">
          <input
            v-model="includeAttachments"
            type="checkbox"
            class="w-4 h-4 rounded border-n-slate-6 text-n-brand focus:ring-n-brand"
          />
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('FORWARD_MESSAGE.INCLUDE_ATTACHMENTS') }}
          </span>
        </label>
      </div>

      <!-- Footer -->
      <div
        class="flex items-center justify-end gap-3 p-4 border-t border-n-weak"
      >
        <button
          class="px-4 py-2 rounded-lg text-sm font-medium text-n-slate-11 hover:bg-n-slate-3 hover:text-n-slate-12 transition-colors"
          @click="closeModal"
        >
          {{ t('FORWARD_MESSAGE.CANCEL') }}
        </button>
        <button
          class="px-6 py-2 rounded-lg bg-n-brand text-white text-sm font-bold shadow-sm hover:bg-n-brand/90 hover:shadow-md transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          :disabled="!canForward"
          @click="forwardToContacts"
        >
          <i v-if="isForwarding" class="i-lucide-loader-2 animate-spin" />
          <i v-else class="i-lucide-send" />
          {{ t('FORWARD_MESSAGE.FORWARD') }}
        </button>
      </div>
    </div>
  </Modal>
</template>
