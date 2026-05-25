<script setup>
import { computed } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';

const { contentAttributes } = useMessageContext();
const { t } = useI18n();

const pixData = computed(() => contentAttributes.value?.uazapiPixButton || {});

const professionalName = computed(() => pixData.value.professionalName || '');
const professionalPhone = computed(() => pixData.value.professionalPhone || '');
const pixType = computed(() => pixData.value.pixType || '');
const pixKey = computed(() => pixData.value.pixKey || '');
const pixName = computed(() => pixData.value.pixName || professionalName.value);

const contentLine = computed(() => {
  return [pixType.value, pixKey.value].filter(Boolean).join(' / ');
});

const copyPixKey = async () => {
  if (!pixKey.value) return;

  try {
    await navigator.clipboard.writeText(pixKey.value);
    useAlert(t('CONVERSATION.SHARED_ATTACHMENT.PIX_KEY_COPIED'));
  } catch {
    useAlert(t('CONVERSATION.SHARED_ATTACHMENT.PIX_KEY_COPY_FAILED'));
  }
};

const action = computed(() => {
  if (!pixKey.value) return null;

  return {
    label: t('CONVERSATION.SHARED_ATTACHMENT.COPY_PIX_KEY'),
    onClick: copyPixKey,
  };
});
</script>

<template>
  <BaseAttachmentBubble
    icon="i-lucide-qr-code"
    icon-bg-color="bg-[#0F766E]"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.PIX"
    :title="professionalName"
    :content="contentLine"
    :action="action"
  >
    <div class="space-y-3 text-sm">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <div v-if="professionalName" class="truncate font-medium text-n-slate-12">
            {{ professionalName }}
          </div>
          <div v-if="professionalPhone" class="truncate text-n-slate-11">
            {{ professionalPhone }}
          </div>
        </div>
        <span
          class="inline-flex shrink-0 items-center rounded-full bg-n-teal-3 px-2.5 py-1 text-xs font-semibold text-n-teal-11"
        >
          PIX
        </span>
      </div>

      <div class="grid gap-2 sm:grid-cols-2">
        <div class="rounded-lg bg-n-slate-2 px-3 py-2">
          <div class="text-xs uppercase tracking-wide text-n-slate-10">
            {{ t('CONVERSATION.SHARED_ATTACHMENT.PIX_TYPE') }}
          </div>
          <div class="mt-1 font-medium text-n-slate-12">
            {{ pixType || '-' }}
          </div>
        </div>
        <div class="rounded-lg bg-n-slate-2 px-3 py-2">
          <div class="text-xs uppercase tracking-wide text-n-slate-10">
            {{ t('CONVERSATION.SHARED_ATTACHMENT.PIX_NAME') }}
          </div>
          <div class="mt-1 truncate font-medium text-n-slate-12">
            {{ pixName || '-' }}
          </div>
        </div>
      </div>

      <div class="rounded-lg bg-n-slate-2 px-3 py-2">
        <div class="text-xs uppercase tracking-wide text-n-slate-10">
          {{ t('CONVERSATION.SHARED_ATTACHMENT.PIX_KEY') }}
        </div>
        <div class="mt-1 break-all font-medium text-n-slate-12">
          {{ pixKey || '-' }}
        </div>
      </div>
    </div>
  </BaseAttachmentBubble>
</template>