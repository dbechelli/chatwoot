import MessageApi from '../../../../api/inbox/message';

export default {
  async forwardMessage(_, { conversationId, messageId, contactIds }) {
    try {
      const response = await MessageApi.forwardMessage(
        conversationId,
        messageId,
        contactIds
      );
      return response.data;
    } catch (error) {
      throw error;
    }
  },
};
