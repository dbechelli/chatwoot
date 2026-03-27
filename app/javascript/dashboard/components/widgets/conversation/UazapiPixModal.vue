<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactAPI from 'dashboard/api/contacts';
import { debounce } from '@chatwoot/utils';

const PROFESSIONAL_ATTRIBUTE_KEY = 'profissional';
const PIX_TYPE_ATTRIBUTE_KEY = 'pix_type';
const PIX_KEY_ATTRIBUTE_KEY = 'pix_key';
const PIX_NAME_ATTRIBUTE_KEY = 'pix_name';
const PROFESSIONAL_VALUES = ['s', 'sim', 'true', '1', 'yes', 'y'];

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'submit']);

const { t } = useI18n();

const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const selectedProfessional = ref(null);

const normalizeCustomAttributes = contact => {
  return contact.custom_attributes || contact.customAttributes || {};
};

const isProfessional = contact => {
  const value = normalizeCustomAttributes(contact)[PROFESSIONAL_ATTRIBUTE_KEY];
  if (value === true) return true;
  return PROFESSIONAL_VALUES.includes(String(value || '').trim().toLowerCase());
};

const normalizePixType = value => {
  const normalized = String(value || '').trim().toUpperCase();
  const aliases = {
    TELEFONE: 'PHONE',
    PHONE: 'PHONE',
    CELULAR: 'PHONE',
    EMAIL: 'EMAIL',
    CPF: 'CPF',
    CNPJ: 'CNPJ',
    EVP: 'EVP',
    ALEATORIA: 'EVP',
    ALEATORIO: 'EVP',
    RANDOM: 'EVP',
  };

  return aliases[normalized] || normalized;
};

const selectedPixData = computed(() => {
  if (!selectedProfessional.value) return null;

  const customAttributes = normalizeCustomAttributes(selectedProfessional.value);
  const pixType = normalizePixType(customAttributes[PIX_TYPE_ATTRIBUTE_KEY]);
  const pixKey = String(customAttributes[PIX_KEY_ATTRIBUTE_KEY] || '').trim();
  const pixName =
    String(customAttributes[PIX_NAME_ATTRIBUTE_KEY] || '').trim() ||
    selectedProfessional.value.name ||
    '';

  return {
    professionalId: selectedProfessional.value.id,
    professionalName: selectedProfessional.value.name || '',
    professionalPhone:
      selectedProfessional.value.phone_number || selectedProfessional.value.phoneNumber || '',
    pixType,
    pixKey,
    pixName,
  };
});

const hasValidPixConfig = computed(() => {
  return Boolean(selectedPixData.value?.pixType && selectedPixData.value?.pixKey);
});

const canSubmit = computed(() => {
  return Boolean(selectedProfessional.value && hasValidPixConfig.value);
});

const resetState = () => {
  searchQuery.value = '';
  searchResults.value = [];
  isSearching.value = false;
  selectedProfessional.value = null;
};

const selectProfessional = contact => {
  selectedProfessional.value = contact;
  searchQuery.value = contact.name || '';
  searchResults.value = [];
};

const performSearch = debounce(async query => {
  if (!query?.trim()) {
    searchResults.value = [];
    isSearching.value = false;
    return;
  }

  isSearching.value = true;

  try {
    const {
      data: { payload },
    } = await ContactAPI.search(query.trim());

    searchResults.value = (payload || []).filter(isProfessional);
  } catch {
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
}, 300);

const closeModal = () => {
  resetState();
  emit('close');
};

const submitForm = () => {
  if (!canSubmit.value) return;

  emit('submit', {
    professionalId: selectedPixData.value.professionalId,
    professionalName: selectedPixData.value.professionalName,
    professionalPhone: selectedPixData.value.professionalPhone,
    pixType: selectedPixData.value.pixType,
    pixKey: selectedPixData.value.pixKey,
    pixName: selectedPixData.value.pixName,
  });

  resetState();
};

watch(
  () => props.show,
  value => {
    if (!value) resetState();
  }
);

watch(searchQuery, value => {
  if (!value?.trim()) {
    searchResults.value = [];
    isSearching.value = false;
    selectedProfessional.value = null;
    return;
  }

  if (selectedProfessional.value && value !== selectedProfessional.value.name) {
    selectedProfessional.value = null;
  }

  isSearching.value = true;
  performSearch(value);
});
</script>

<template>
  <Modal :show="show" :on-close="closeModal" :show-close-button="false">
    <div class="flex flex-col h-full max-h-[80vh] w-full">
      <div class="flex items-center justify-between p-6 border-b border-n-weak bg-white">
        <div class="flex-1">
          <h2 class="text-xl font-semibold text-n-slate-12">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.DESCRIPTION') }}
          </p>
        </div>
        <button
          class="p-2 rounded-lg hover:bg-n-slate-3 transition-colors flex items-center justify-center text-n-slate-10 hover:text-n-slate-12 ml-4"
          @click="closeModal"
        >
          <i class="i-lucide-x text-xl" />
        </button>
      </div>

      <div class="flex-1 overflow-y-auto p-6 bg-n-slate-1 space-y-4">
        <div class="space-y-2">
          <label class="block text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.SEARCH_LABEL') }}
          </label>
          <div class="relative">
            <i
              class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 text-n-slate-10 text-base"
            />
            <input
              v-model="searchQuery"
              type="text"
              :placeholder="
                t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.SEARCH_PLACEHOLDER')
              "
              class="w-full pl-10 pr-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>

          <div
            v-if="isSearching || searchResults.length"
            class="rounded-xl border border-n-weak bg-white overflow-hidden"
          >
            <div v-if="isSearching" class="px-4 py-3 text-sm text-n-slate-11">
              {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.SEARCHING') }}
            </div>
            <button
              v-for="contact in searchResults"
              v-else
              :key="contact.id"
              class="w-full px-4 py-3 text-left transition-colors hover:bg-n-slate-2 border-b last:border-b-0 border-n-weak"
              @click="selectProfessional(contact)"
            >
              <div class="flex items-center justify-between gap-3">
                <div class="min-w-0">
                  <div class="text-sm font-medium text-n-slate-12 truncate">
                    {{ contact.name || t('FORWARD_MESSAGE.UNKNOWN_CONTACT') }}
                  </div>
                  <div class="text-xs text-n-slate-11 truncate">
                    {{
                      contact.phone_number ||
                      contact.email ||
                      t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.NO_CONTACT_INFO')
                    }}
                  </div>
                </div>
                <span class="text-xs font-medium text-n-brand whitespace-nowrap">
                  {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.USE_PROFESSIONAL') }}
                </span>
              </div>
            </button>
          </div>

          <p v-else-if="searchQuery.trim()" class="text-xs text-n-slate-11">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.NO_RESULTS') }}
          </p>
        </div>

        <div
          v-if="selectedProfessional"
          class="rounded-2xl border border-n-weak bg-white p-4 shadow-sm space-y-4"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0 space-y-1">
              <p class="text-xs font-medium uppercase tracking-wide text-n-slate-10">
                {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.SELECTED_PROFESSIONAL') }}
              </p>
              <h3 class="text-base font-semibold text-n-slate-12 truncate">
                {{ selectedPixData?.professionalName }}
              </h3>
              <p class="text-sm text-n-slate-11 truncate">
                {{
                  selectedPixData?.professionalPhone ||
                  t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.NO_CONTACT_INFO')
                }}
              </p>
            </div>
            <span
              class="inline-flex items-center rounded-full bg-n-brand/10 px-3 py-1 text-xs font-medium text-n-brand"
            >
              PIX
            </span>
          </div>

          <div class="grid gap-3 sm:grid-cols-2">
            <div class="rounded-xl bg-n-slate-2 p-3">
              <p class="text-xs uppercase tracking-wide text-n-slate-10">
                {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.PIX_TYPE') }}
              </p>
              <p class="mt-1 text-sm font-medium text-n-slate-12">
                {{ selectedPixData?.pixType || '-' }}
              </p>
            </div>
            <div class="rounded-xl bg-n-slate-2 p-3">
              <p class="text-xs uppercase tracking-wide text-n-slate-10">
                {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.PIX_NAME') }}
              </p>
              <p class="mt-1 text-sm font-medium text-n-slate-12 truncate">
                {{ selectedPixData?.pixName || '-' }}
              </p>
            </div>
          </div>

          <div class="rounded-xl bg-n-slate-2 p-3">
            <p class="text-xs uppercase tracking-wide text-n-slate-10">
              {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.PIX_KEY') }}
            </p>
            <p class="mt-1 break-all text-sm font-medium text-n-slate-12">
              {{ selectedPixData?.pixKey || '-' }}
            </p>
          </div>

          <p
            v-if="!hasValidPixConfig"
            class="rounded-xl border border-n-ruby-7/20 bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
          >
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.MISSING_PIX_DATA') }}
          </p>
        </div>
      </div>

      <div class="flex items-center justify-end gap-3 p-4 border-t border-n-weak bg-white">
        <Button
          slate
          :label="t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.CANCEL')"
          @click="closeModal"
        />
        <Button
          blue
          :label="t('CONVERSATION.REPLYBOX.MORE_ACTIONS.PIX_MODAL.SUBMIT')"
          :disabled="!canSubmit"
          @click="submitForm"
        />
      </div>
    </div>
  </Modal>
</template>