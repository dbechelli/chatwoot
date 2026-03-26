<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  name: 'AddCanned',
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      shortCode: '',
      content: this.responseContent || '',
      attachments: [],
      addCanned: {
        showLoading: false,
        message: '',
      },
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
    selectedAttachments() {
      return Array.from(this.attachments || []);
    },
    hasContentOrAttachment() {
      return Boolean(this.content?.trim() || this.selectedAttachments.length);
    },
  },
  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.attachments = [];
      if (this.$refs.fileInput) {
        this.$refs.fileInput.value = '';
      }
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    onFileChange(e) {
      this.attachments = e.target.files;
    },
    addCannedResponse() {
      // Show loading on button
      this.addCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('createCannedResponse', {
          short_code: this.shortCode,
          content: this.content,
          attachments: this.attachments,
        })
        .then(() => {
          // Reset Form, Show success message
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
          this.resetForm();
          this.onClose();
        })
        .catch(error => {
          this.addCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
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
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CANNED_MGMT.ADD.TITLE')"
        :header-content="$t('CANNED_MGMT.ADD.DESC')"
      />
      <form class="flex flex-col w-full" @submit.prevent="addCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              @blur="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: !hasContentOrAttachment && v$.content.$dirty }">
            {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: !hasContentOrAttachment && v$.content.$dirty }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
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
              @change="onFileChange"
            />
          </label>
          <p class="text-sm text-n-slate-11 mt-1">
            {{ $t('CANNED_MGMT.ATTACHMENTS.HELP_TEXT') }}
          </p>
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
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
            :disabled="
              !hasContentOrAttachment ||
              v$.shortCode.$invalid ||
              addCanned.showLoading
            "
            :is-loading="addCanned.showLoading"
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
