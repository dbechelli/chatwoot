<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const shouldBeWebhookUrl = (value = '') =>
  value ? value.startsWith('http') : true;

const isBlank = value => !value || !value.trim();

const isCompleteUazapiConfig = (_, vm) => {
  const hasBaseUrl = !isBlank(vm.uazapiBaseUrl);
  const hasToken = !isBlank(vm.uazapiToken);

  return hasBaseUrl === hasToken;
};

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      channelName: '',
      webhookUrl: '',
      uazapiBaseUrl: '',
      uazapiToken: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { required },
    webhookUrl: { shouldBeWebhookUrl },
    uazapiBaseUrl: {
      shouldBeWebhookUrl,
      isCompleteUazapiConfig,
    },
    uazapiToken: {
      isCompleteUazapiConfig,
    },
  },
  methods: {
    buildApiChannelAdditionalAttributes() {
      if (isBlank(this.uazapiBaseUrl) && isBlank(this.uazapiToken)) {
        return {};
      }

      return {
        provider: 'uazapi',
        uazapi_base_url: this.uazapiBaseUrl.trim(),
        uazapi_token: this.uazapiToken,
      };
    },
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const apiChannel = await this.$store.dispatch('inboxes/createChannel', {
          name: this.channelName?.trim(),
          channel: {
            type: 'api',
            webhook_url: this.webhookUrl,
            additional_attributes: this.buildApiChannelAdditionalAttributes(),
          },
        });

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: apiChannel.id,
          },
        });
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.ADD.API_CHANNEL.API.ERROR_MESSAGE'));
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t('INBOX_MGMT.ADD.API_CHANNEL.TITLE')"
      :header-content="$t('INBOX_MGMT.ADD.API_CHANNEL.DESC')"
    />
    <form
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createChannel()"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">{{
            $t('INBOX_MGMT.ADD.API_CHANNEL.CHANNEL_NAME.ERROR')
          }}</span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.webhookUrl.$error }">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.LABEL') }}
          <input
            v-model="webhookUrl"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.PLACEHOLDER')
            "
            @blur="v$.webhookUrl.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.WEBHOOK_URL.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label
          :class="{
            error: v$.uazapiBaseUrl.$error || v$.uazapiToken.$error,
          }"
        >
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.UAZAPI_BASE_URL.LABEL') }}
          <input
            v-model="uazapiBaseUrl"
            type="text"
            name="uazapi_base_url"
            autocomplete="off"
            autocapitalize="off"
            autocorrect="off"
            spellcheck="false"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.UAZAPI_BASE_URL.PLACEHOLDER')
            "
            @blur="v$.uazapiBaseUrl.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.UAZAPI_BASE_URL.SUBTITLE') }}
        </p>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label
          :class="{
            error: v$.uazapiBaseUrl.$error || v$.uazapiToken.$error,
          }"
        >
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.UAZAPI_TOKEN.LABEL') }}
          <input
            v-model="uazapiToken"
            type="password"
            name="uazapi_token"
            autocomplete="new-password"
            autocapitalize="off"
            autocorrect="off"
            spellcheck="false"
            :placeholder="
              $t('INBOX_MGMT.ADD.API_CHANNEL.UAZAPI_TOKEN.PLACEHOLDER')
            "
            @blur="v$.uazapiToken.$touch"
          />
        </label>
        <p class="help-text">
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.UAZAPI_TOKEN.SUBTITLE') }}
        </p>
        <p
          v-if="v$.uazapiBaseUrl.$error || v$.uazapiToken.$error"
          class="help-text text-n-ruby-9"
        >
          {{ $t('INBOX_MGMT.ADD.API_CHANNEL.UAZAPI_ERROR') }}
        </p>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          :label="$t('INBOX_MGMT.ADD.API_CHANNEL.SUBMIT_BUTTON')"
        />
      </div>
    </form>
  </div>
</template>
