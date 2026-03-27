<script setup>
import { computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';

const { attachments } = useMessageContext();

const $store = useStore();
const { t } = useI18n();

const attachment = computed(() => {
  return attachments.value[0];
});

const attachmentMeta = computed(() => attachment.value?.meta ?? {});

const phoneNumber = computed(() => {
  return attachment.value?.fallbackTitle || '';
});

const contactName = computed(() => {
  const { fullName, firstName, lastName } = attachmentMeta.value;
  return fullName || `${firstName ?? ''} ${lastName ?? ''}`.trim();
});

const organization = computed(() => attachmentMeta.value.organization || '');

const email = computed(() => attachmentMeta.value.email || '');

const url = computed(() => attachmentMeta.value.url || '');

const formattedPhoneNumberDisplay = computed(() => {
  return phoneNumber.value
    .split(',')
    .map(number => number.trim())
    .filter(Boolean)
    .join(' • ');
});

const formattedPhoneNumber = computed(() => {
  return phoneNumber.value.replace(/\s|-|[A-Za-z]/g, '');
});

const rawPhoneNumber = computed(() => {
  return phoneNumber.value
    .split(',')
    .map(number => number.replace(/\D/g, ''))
    .find(Boolean) || '';
});

function getContactObject() {
  const contactItem = {
    name: contactName.value,
    phone_number: `+${rawPhoneNumber.value}`,
  };
  return contactItem;
}

async function filterContactByNumber(searchCandidate) {
  const query = {
    attribute_key: 'phone_number',
    filter_operator: 'equal_to',
    values: [searchCandidate],
    attribute_model: 'standard',
    custom_attribute_type: '',
  };

  const queryPayload = { payload: [query] };
  const contacts = await $store.dispatch('contacts/filter', {
    queryPayload,
    resetState: false,
  });
  return contacts.shift();
}

function openContactNewTab(contactId) {
  const accountId = window.location.pathname.split('/')[3];
  const url = `/app/accounts/${accountId}/contacts/${contactId}`;
  window.open(url, '_blank');
}

async function addContact() {
  try {
    let contact = await filterContactByNumber(rawPhoneNumber);
    if (!contact) {
      contact = await $store.dispatch('contacts/create', getContactObject());
      useAlert(t('CONTACT_FORM.SUCCESS_MESSAGE'));
    }
    openContactNewTab(contact.id);
  } catch (error) {
    if (error instanceof DuplicateContactException) {
      if (error.data.includes('phone_number')) {
        useAlert(t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
      }
    } else if (error instanceof ExceptionWithMessage) {
      useAlert(error.data);
    } else {
      useAlert(t('CONTACT_FORM.ERROR_MESSAGE'));
    }
  }
}

const action = computed(() => ({
  label: t('CONVERSATION.SAVE_CONTACT'),
  onClick: addContact,
}));
</script>

<template>
  <BaseAttachmentBubble
    icon="i-teenyicons-user-circle-solid"
    icon-bg-color="bg-[#D6409F]"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.CONTACT"
    :title="contactName"
    :content="formattedPhoneNumberDisplay"
    :action="formattedPhoneNumber ? action : null"
  >
    <div v-if="contactName" class="truncate text-sm text-n-slate-12">
      {{ contactName }}
    </div>
    <div class="space-y-1 text-sm text-n-slate-11">
      <div v-if="formattedPhoneNumberDisplay" class="truncate">
        {{ formattedPhoneNumberDisplay }}
      </div>
      <div v-if="organization" class="truncate">
        {{ organization }}
      </div>
      <div v-if="email" class="truncate">
        {{ email }}
      </div>
      <div v-if="url" class="truncate">
        {{ url }}
      </div>
    </div>
  </BaseAttachmentBubble>
</template>
