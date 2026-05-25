<script>
/* eslint no-console: 0 */
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';

export default {
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    id: { type: Number, default: null },
    edcontent: { type: String, default: '' },
    edshortCode: { type: String, default: '' },
    attachments: { type: Array, default: () => [] },
    additionalAttributes: { type: Object, default: () => ({}) },
    onClose: { type: Function, default: () => {} },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      editCanned: {
        showAlert: false,
        showLoading: false,
      },
      shortCode: this.edshortCode,
      content: this.edcontent,
      attachments: [],
      existingAttachments: [...this.attachments],
      show: true,
    };
  },
  validations() {
    return {
      shortCode: {
        required,
        minLength: minLength(2),
      },
      content: {
        required: () => this.hasContentOrAttachment,
      },
    };
  },
  computed: {
    pageTitle() {
      return `${this.$t('CANNED_MGMT.EDIT.TITLE')} - ${this.edshortCode}`;
    },
    selectedAttachments() {
      return Array.from(this.attachments || []);
    },
    hasContentOrAttachment() {
      return Boolean(
        this.content?.trim() ||
          this.selectedAttachments.length ||
          this.existingAttachments.length
      );
    },
    retainRemoteMedia() {
      if (!this.additionalAttributes?.uazapi_remote_file_url) return true;

      return this.existingAttachments.some(
        attachment => attachment.url === this.additionalAttributes.uazapi_remote_file_url
      );
    },
    isReadOnlyUazapiTemplate() {
      return this.additionalAttributes?.uazapi_on_whatsapp === true;
    },
  },
  methods: {
    setPageName({ name }) {
      this.v$.content.$touch();
      this.content = name;
    },
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.attachments = [];
      this.existingAttachments = [];
      if (this.$refs.fileInput) {
        this.$refs.fileInput.value = '';
      }
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    onFileChange(e) {
      this.attachments = e.target.files;
    },
    editCannedResponse() {
      // Show loading on button
      this.editCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('updateCannedResponse', {
          id: this.id,
          short_code: this.shortCode,
          content: this.content,
          attachments: this.attachments,
          retained_attachment_ids: this.existingAttachments
            .map(attachment => attachment.id)
            .filter(attachmentId => Number.isInteger(attachmentId)),
          retain_remote_media: this.retainRemoteMedia,
        })
        .then(() => {
          // Reset Form, Show success message
          this.editCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          this.resetForm();
          setTimeout(() => {
            this.onClose();
          }, 10);
        })
        .catch(error => {
          this.editCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.EDIT.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
    removeSelectedAttachment(index) {
      const nextAttachments = this.selectedAttachments.filter(
        (_, fileIndex) => fileIndex !== index
      );
      this.attachments = nextAttachments;
      if (this.$refs.fileInput) {
        const dataTransfer = new DataTransfer();
        nextAttachments.forEach(file => dataTransfer.items.add(file));
        this.$refs.fileInput.files = dataTransfer.files;
      }
    },
    removeExistingAttachment(attachmentId) {
      this.existingAttachments = this.existingAttachments.filter(
        attachment => attachment.id !== attachmentId
      );
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="pageTitle" />
      <form class="flex flex-col w-full" @submit.prevent="editCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :disabled="isReadOnlyUazapiTemplate"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.SHORT_CODE.PLACEHOLDER')"
              @input="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: !hasContentOrAttachment && v$.content.$dirty }">
            {{ $t('CANNED_MGMT.EDIT.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: !hasContentOrAttachment && v$.content.$dirty }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :disabled="isReadOnlyUazapiTemplate"
              :placeholder="$t('CANNED_MGMT.EDIT.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <div class="w-full">
          <label>
            {{ $t('CANNED_MGMT.ATTACHMENTS.LABEL') }}
            <input
              ref="fileInput"
              type="file"
              multiple
              :disabled="isReadOnlyUazapiTemplate"
              @change="onFileChange"
            />
          </label>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ $t('CANNED_MGMT.ATTACHMENTS.HELP_TEXT') }}
          </p>
          <div v-if="existingAttachments.length" class="mt-3 flex flex-col gap-2">
            <div
              v-for="attachment in existingAttachments"
              :key="attachment.id"
              class="flex items-center justify-between rounded-lg border border-n-slate-3 px-3 py-2"
            >
              <span class="text-sm text-n-slate-12 truncate pr-3">
                {{ attachment.filename }}
              </span>
              <button
                v-if="!isReadOnlyUazapiTemplate"
                type="button"
                class="text-sm text-n-ruby-11"
                @click="removeExistingAttachment(attachment.id)"
              >
                {{ $t('CANNED_MGMT.ATTACHMENTS.REMOVE') }}
              </button>
            </div>
          </div>
          <div v-if="selectedAttachments.length" class="mt-3 flex flex-col gap-2">
            <div
              v-for="(attachment, index) in selectedAttachments"
              :key="`${attachment.name}-${attachment.size}-${index}`"
              class="flex items-center justify-between rounded-lg border border-n-slate-3 px-3 py-2"
            >
              <span class="text-sm text-n-slate-12 truncate pr-3">
                {{ attachment.name }}
              </span>
              <button
                type="button"
                class="text-sm text-n-ruby-11"
                @click="removeSelectedAttachment(index)"
              >
                {{ $t('CANNED_MGMT.ATTACHMENTS.REMOVE') }}
              </button>
            </div>
          </div>
          <p
            v-if="isReadOnlyUazapiTemplate"
            class="mt-3 text-sm text-n-amber-11"
          >
            {{ $t('CANNED_MGMT.UAZAPI.READ_ONLY') }}
          </p>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')"
            :disabled="
              !hasContentOrAttachment ||
              v$.shortCode.$invalid ||
              editCanned.showLoading ||
              isReadOnlyUazapiTemplate
            "
            :is-loading="editCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
::v-deep {
  .ProseMirror-menubar {
    @apply hidden;
  }

  .ProseMirror-woot-style {
    @apply min-h-[12.5rem];

    p {
      @apply text-base;
    }
  }
}
</style>
