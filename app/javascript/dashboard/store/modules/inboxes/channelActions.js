import * as types from '../../mutation-types';
import InboxesAPI from '../../../api/inboxes';
import AnalyticsHelper from '../../../helper/AnalyticsHelper';
import { ACCOUNT_EVENTS } from '../../../helper/AnalyticsHelper/events';

const isBlobLike = value =>
  typeof Blob !== 'undefined' && value instanceof Blob;

const isFileLike = value =>
  typeof File !== 'undefined' && value instanceof File;

const appendFormDataValue = (formData, key, value) => {
  if (value === undefined) {
    return;
  }

  if (
    value === null ||
    isBlobLike(value) ||
    isFileLike(value) ||
    value instanceof Date
  ) {
    formData.append(key, value);
    return;
  }

  if (Array.isArray(value)) {
    if (!value.length) {
      formData.append(`${key}[]`, '');
      return;
    }

    value.forEach(item => appendFormDataValue(formData, `${key}[]`, item));
    return;
  }

  if (typeof value === 'object') {
    Object.keys(value).forEach(nestedKey => {
      appendFormDataValue(formData, `${key}[${nestedKey}]`, value[nestedKey]);
    });
    return;
  }

  formData.append(key, value);
};

export const buildInboxData = inboxParams => {
  const formData = new FormData();
  const { channel = {}, ...inboxProperties } = inboxParams;
  Object.keys(inboxProperties).forEach(key => {
    appendFormDataValue(formData, key, inboxProperties[key]);
  });
  const { selectedFeatureFlags, ...channelParams } = channel;
  // selectedFeatureFlags needs to be empty when creating a website channel
  if (selectedFeatureFlags) {
    if (selectedFeatureFlags.length) {
      selectedFeatureFlags.forEach(featureFlag => {
        formData.append(`channel[selected_feature_flags][]`, featureFlag);
      });
    } else {
      formData.append('channel[selected_feature_flags][]', '');
    }
  }
  Object.keys(channelParams).forEach(key => {
    appendFormDataValue(formData, `channel[${key}]`, channelParams[key]);
  });
  return formData;
};

const sendAnalyticsEvent = channelType => {
  AnalyticsHelper.track(ACCOUNT_EVENTS.ADDED_AN_INBOX, {
    channelType,
  });
};

export const channelActions = {
  createVoiceChannel: async ({ commit }, params) => {
    try {
      commit(types.default.SET_INBOXES_UI_FLAG, { isCreating: true });
      const response = await InboxesAPI.create({
        name: params.name,
        channel: { ...params.voice, type: 'voice' },
      });
      commit(types.default.ADD_INBOXES, response.data);
      commit(types.default.SET_INBOXES_UI_FLAG, { isCreating: false });
      sendAnalyticsEvent('voice');
      return response.data;
    } catch (error) {
      commit(types.default.SET_INBOXES_UI_FLAG, { isCreating: false });
      throw error;
    }
  },
};
