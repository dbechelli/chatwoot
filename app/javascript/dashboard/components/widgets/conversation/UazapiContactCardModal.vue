<script setup>
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactAPI from 'dashboard/api/contacts';
import { debounce } from '@chatwoot/utils';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'submit']);

const { t } = useI18n();

const form = reactive({
  fullName: '',
  phoneNumber: '',
  organization: '',
  email: '',
  url: '',
});

const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);

const canSubmit = computed(() => {
  return Boolean(form.fullName.trim() && form.phoneNumber.trim());
});

const resetForm = () => {
  form.fullName = '';
  form.phoneNumber = '';
  form.organization = '';
  form.email = '';
  form.url = '';
  searchQuery.value = '';
  searchResults.value = [];
  isSearching.value = false;
};

const fillContactData = contact => {
  const additionalAttributes = contact.additional_attributes || {};

  form.fullName = contact.name || '';
  form.phoneNumber = contact.phone_number || '';
  form.organization =
    additionalAttributes.companyName || additionalAttributes.company_name || '';
  form.email = contact.email || '';
  form.url =
    additionalAttributes.website ||
    additionalAttributes.website_url ||
    additionalAttributes.site ||
    '';
};

const selectContact = contact => {
  fillContactData(contact);
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
    searchResults.value = payload || [];
  } catch {
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
}, 300);

const closeModal = () => {
  resetForm();
  emit('close');
};

const submitForm = () => {
  if (!canSubmit.value) return;

  emit('submit', {
    fullName: form.fullName.trim(),
    phoneNumber: form.phoneNumber.trim(),
    organization: form.organization.trim(),
    email: form.email.trim(),
    url: form.url.trim(),
  });

  resetForm();
};

watch(
  () => props.show,
  value => {
    if (!value) resetForm();
  }
);

watch(searchQuery, value => {
  if (!value?.trim()) {
    searchResults.value = [];
    isSearching.value = false;
    return;
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
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.DESCRIPTION') }}
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
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.SEARCH_LABEL') }}
          </label>
          <div class="relative">
            <i
              class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 text-n-slate-10 text-base"
            />
            <input
              v-model="searchQuery"
              type="text"
              :placeholder="
                t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.SEARCH_PLACEHOLDER')
              "
              class="w-full pl-10 pr-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>
          <div
            v-if="isSearching || searchResults.length"
            class="rounded-xl border border-n-weak bg-white overflow-hidden"
          >
            <div
              v-if="isSearching"
              class="px-4 py-3 text-sm text-n-slate-11"
            >
              {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.SEARCHING') }}
            </div>
            <button
              v-for="contact in searchResults"
              v-else
              :key="contact.id"
              class="w-full px-4 py-3 text-left transition-colors hover:bg-n-slate-2 border-b last:border-b-0 border-n-weak"
              @click="selectContact(contact)"
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
                      t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.NO_CONTACT_INFO')
                    }}
                  </div>
                </div>
                <span class="text-xs font-medium text-n-brand whitespace-nowrap">
                  {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.USE_CONTACT') }}
                </span>
              </div>
            </button>
          </div>
          <p
            v-else-if="searchQuery.trim()"
            class="text-xs text-n-slate-11"
          >
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.NO_RESULTS') }}
          </p>
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.FULL_NAME') }}
          </label>
          <input
            v-model="form.fullName"
            type="text"
            class="w-full px-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
          />
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.PHONE_NUMBER') }}
          </label>
          <input
            v-model="form.phoneNumber"
            type="text"
            class="w-full px-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
          />
          <p class="text-xs text-n-slate-11">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.PHONE_HELP') }}
          </p>
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.ORGANIZATION') }}
          </label>
          <input
            v-model="form.organization"
            type="text"
            class="w-full px-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
          />
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.EMAIL') }}
          </label>
          <input
            v-model="form.email"
            type="email"
            class="w-full px-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
          />
        </div>

        <div class="space-y-2">
          <label class="block text-sm font-medium text-n-slate-12">
            {{ t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.URL') }}
          </label>
          <input
            v-model="form.url"
            type="url"
            class="w-full px-4 py-2.5 rounded-lg border border-n-weak bg-white text-n-slate-12 placeholder-n-slate-10 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
          />
        </div>
      </div>

      <div class="flex items-center justify-end gap-3 p-4 border-t border-n-weak bg-white">
        <Button
          slate
          :label="t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.CANCEL')"
          @click="closeModal"
        />
        <Button
          blue
          :label="t('CONVERSATION.REPLYBOX.MORE_ACTIONS.CONTACT_MODAL.SUBMIT')"
          :disabled="!canSubmit"
          @click="submitForm"
        />
      </div>
    </div>
  </Modal>
</template>