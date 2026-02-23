/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  getPreviousResolvedConversations(conversationID, limit = 1, beforeId = null) {
    const params = { limit };
    if (beforeId) {
      params.before_id = beforeId;
    }
    return axios.get(`${this.url}/${conversationID}/previous_resolved`, {
      params,
    });
  }

  getWhatsappGroups() {
    return axios.get(`${this.url}/whatsapp_groups`);
  }
}

export default new ConversationApi();
