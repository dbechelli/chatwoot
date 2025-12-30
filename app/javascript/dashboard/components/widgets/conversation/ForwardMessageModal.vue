<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Modal from 'dashboard/components/Modal.vue';
import Avatar from 'next/avatar/Avatar.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  conversationId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['close', 'forward']);

const store = useStore();
const { t } = useI18n();

const searchQuery = ref('');
const selectedContacts = ref([]);
const isForwarding = ref(false);
const includeAttachments = ref(true);

const conversation = computed(() =>
  store.getters.getConversationById(props.conversationId)
);

const allContacts = computed(() => store.getters['contacts/getContacts'] || []);

const filteredContacts = computed(() => {
  if (!searchQuery.value) {
    return allContacts.value.slice(0, 50); // Limitar a 50 para performance
  }

  const query = searchQuery.value.toLowerCase();
  return allContacts.value
    .filter(contact => {
      const name = contact.name?.toLowerCase() || '';
      const email = contact.email?.toLowerCase() || '';
      const phone = contact.phone_number?.toLowerCase() || '';
      return (
        name.includes(query) || email.includes(query) || phone.includes(query)
      );
    })
    .slice(0, 50);
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
  emit('close');
};

const forwardToContacts = async () => {
  if (!canForward.value) return;

  isForwarding.value = true;

  try {
    // Buscar mensagens da conversa
    const messages = conversation.value?.messages || [];
    const lastMessage = messages[messages.length - 1];

    if (!lastMessage) {
      useAlert(t('FORWARD_MESSAGE.NO_MESSAGES'));
      isForwarding.value = false;
      return;
    }

    const inboxId = conversation.value.inbox_id;
    const messageContent = `📨 Mensagem encaminhada:\n\n${lastMessage.content}`;

    // Encaminhar para todos os contatos em paralelo
    const forwardPromises = selectedContacts.value.map(async contactId => {
      const contact = allContacts.value.find(c => c.id === contactId);
      if (!contact) {
        return { success: false, contactId };
      }

      try {
        await store.dispatch('sendMessage', {
          conversationId: null,
          message: {
            content: messageContent,
            private: false,
          },
          contactId,
          inboxId,
        });
        return { success: true, contactId };
      } catch (error) {
        return { success: false, contactId, error };
      }
    });

    const results = await Promise.all(forwardPromises);
    const successCount = results.filter(r => r.success).length;
    const errorCount = results.filter(r => !r.success).length;

    // Mostrar resultado
    if (successCount > 0) {
      useAlert(
        t('CONVERSATION.FORWARD_MESSAGE.SUCCESS', { count: successCount })
      );
    }

    if (errorCount > 0) {
      useAlert(t('CONVERSATION.FORWARD_MESSAGE.ERROR'));
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
  <Modal :show="show" :on-close="closeModal">
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
          class="p-2 rounded-lg hover:bg-n-slate-3 transition-colors"
          @click="closeModal"
        >
          <i class="i-lucide-x text-xl text-n-slate-11" />
        </button>
      </div>

      <!-- Contatos selecionados (tags) -->
      <div
        v-if="selectedContacts.length > 0"
        class="flex flex-wrap gap-2 p-4 border-b border-n-weak bg-n-slate-2"
      >
        <div
          v-for="contactId in selectedContacts"
          :key="contactId"
          class="inline-flex items-center gap-2 px-3 py-1.5 bg-n-brand/10 text-n-brand rounded-full text-sm"
        >
          <span>
            {{
              allContacts.find(c => c.id === contactId)?.name || 'Desconhecido'
            }}
          </span>
          <button
            class="hover:bg-n-brand/20 rounded-full p-0.5"
            @click="toggleContact(contactId)"
          >
            <i class="i-lucide-x text-sm" />
          </button>
        </div>
        <div class="text-sm text-n-slate-11 flex items-center">
          {{
            t('FORWARD_MESSAGE.SELECTED_COUNT', {
              count: selectedContacts.length,
            })
          }}
        </div>
      </div>

      <!-- Busca -->
      <div class="p-4 border-b border-n-weak">
        <div class="relative">
          <i
            class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 text-n-slate-11"
          />
          <input
            v-model="searchQuery"
            type="text"
            :placeholder="t('FORWARD_MESSAGE.SEARCH_PLACEHOLDER')"
            class="w-full pl-10 pr-4 py-2 rounded-lg border border-n-weak bg-n-slate-1 text-n-slate-12 placeholder-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand"
          />
        </div>
      </div>

      <!-- Lista de contatos -->
      <div class="flex-1 overflow-y-auto p-4">
        <div
          v-if="filteredContacts.length === 0"
          class="flex flex-col items-center justify-center py-12 text-center"
        >
          <i class="i-lucide-users text-4xl text-n-slate-11 mb-4" />
          <p class="text-n-slate-11">
            {{ t('FORWARD_MESSAGE.NO_CONTACTS') }}
          </p>
        </div>

        <div v-else class="space-y-1">
          <button
            v-for="contact in filteredContacts"
            :key="contact.id"
            class="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-n-slate-2 transition-colors"
            :class="{
              'bg-n-brand/10': isContactSelected(contact.id),
            }"
            @click="toggleContact(contact.id)"
          >
            <!-- Checkbox -->
            <div
              class="flex-shrink-0 w-5 h-5 rounded border-2 flex items-center justify-center transition-colors"
              :class="
                isContactSelected(contact.id)
                  ? 'bg-n-brand border-n-brand'
                  : 'border-n-slate-6'
              "
            >
              <i
                v-if="isContactSelected(contact.id)"
                class="i-lucide-check text-white text-sm"
              />
            </div>

            <!-- Avatar -->
            <Avatar
              :username="contact.name"
              :src="contact.thumbnail"
              size="36px"
            />

            <!-- Informações -->
            <div class="flex-1 text-left min-w-0">
              <p class="font-medium text-n-slate-12 truncate">
                {{ contact.name || t('FORWARD_MESSAGE.UNKNOWN_CONTACT') }}
              </p>
              <p class="text-sm text-n-slate-11 truncate">
                {{ contact.email || contact.phone_number || '-' }}
              </p>
            </div>

            <!-- Badge de última interação -->
            <div
              v-if="contact.last_activity_at"
              class="text-xs text-n-slate-11"
            >
              {{
                new Date(contact.last_activity_at * 1000).toLocaleDateString()
              }}
            </div>
          </button>
        </div>
      </div>

      <!-- Opções -->
      <div class="p-4 border-t border-n-weak">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            v-model="includeAttachments"
            type="checkbox"
            class="w-4 h-4 rounded border-n-slate-6 text-n-brand focus:ring-n-brand"
          />
          <span class="text-sm text-n-slate-12">
            {{ t('FORWARD_MESSAGE.INCLUDE_ATTACHMENTS') }}
          </span>
        </label>
      </div>

      <!-- Footer -->
      <div
        class="flex items-center justify-end gap-3 p-4 border-t border-n-weak"
      >
        <button
          class="px-4 py-2 rounded-lg text-n-slate-12 hover:bg-n-slate-3 transition-colors"
          @click="closeModal"
        >
          {{ t('FORWARD_MESSAGE.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 rounded-lg bg-n-brand text-white hover:bg-n-brand/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          :disabled="!canForward"
          @click="forwardToContacts"
        >
          <i v-if="isForwarding" class="i-lucide-loader-2 animate-spin" />
          <i v-else class="i-lucide-arrow-right" />
          {{ t('FORWARD_MESSAGE.FORWARD') }}
        </button>
      </div>
    </div>
  </Modal>
</template>
