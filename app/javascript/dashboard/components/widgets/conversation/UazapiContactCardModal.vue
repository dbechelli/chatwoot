<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';

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

const canSubmit = computed(() => {
  return Boolean(form.fullName.trim() && form.phoneNumber.trim());
});

const resetForm = () => {
  form.fullName = '';
  form.phoneNumber = '';
  form.organization = '';
  form.email = '';
  form.url = '';
};

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