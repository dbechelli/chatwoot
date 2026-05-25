class Messages::SendOnApiService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Api
  end

  def perform_reply
    return fallback_delivery unless channel.uazapi_enabled?

    channel.validate_uazapi_message!(message)
    message_id = channel.send_message(message)
    message.update!(source_id: message_id) if message_id.present?
    Messages::StatusUpdateService.new(message, 'delivered').perform
  rescue StandardError => e
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end

  def fallback_delivery
    Messages::SendEmailNotificationService.new(message: message).perform
  end
end
