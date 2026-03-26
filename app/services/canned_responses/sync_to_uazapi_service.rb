class CannedResponses::SyncToUazapiService
  include Rails.application.routes.url_helpers

  def initialize(canned_response:)
    @canned_response = canned_response
  end

  def perform!
    configured_api_channels.each do |api_channel|
      ensure_editable!(api_channel)

      response = api_channel.send(:uazapi_client).edit_quick_reply(**quick_reply_payload(api_channel))
      update_canned_response_metadata!(api_channel, response)
    end
  end

  def destroy!
    configured_api_channels.each do |api_channel|
      quick_reply_id = canned_response.uazapi_quick_reply_id(api_channel)
      next if quick_reply_id.blank?

      ensure_editable!(api_channel)
      api_channel.send(:uazapi_client).edit_quick_reply(
        id: quick_reply_id,
        delete: true,
        short_cut: canned_response.short_code,
        type: canned_response.uazapi_message_type
      )
      canned_response.clear_uazapi_metadata!(channel: api_channel)
    end
  end

  private

  attr_reader :canned_response

  def configured_api_channels
    canned_response.account.api_channels.select do |api_channel|
      api_channel.uazapi_enabled? && api_channel.uazapi_base_url.present? && api_channel.uazapi_token.present?
    end
  end

  def ensure_editable!(api_channel)
    quick_reply_id = canned_response.uazapi_quick_reply_id(api_channel)
    return unless quick_reply_id.present? && canned_response.uazapi_on_whatsapp?

    raise I18n.t('errors.uazapi.quick_reply_locked')
  end

  def quick_reply_payload(api_channel)
    payload = media_payload

    {
      id: canned_response.uazapi_quick_reply_id(api_channel),
      short_cut: canned_response.short_code,
      type: payload[:type],
      text: payload[:text],
      file: payload[:file],
      doc_name: payload[:doc_name]
    }
  end

  def media_payload
    attachment = canned_response.attachments.first

    return text_payload if attachment.blank? && canned_response.uazapi_remote_file_url.blank?

    if attachment.present?
      {
        type: attachment_message_type(attachment),
        text: canned_response.content.presence,
        file: attachment_file_reference(attachment),
        doc_name: attachment.filename.to_s.presence
      }
    else
      {
        type: canned_response.uazapi_message_type,
        text: canned_response.content.presence,
        file: canned_response.uazapi_remote_file_url,
        doc_name: canned_response.uazapi_remote_doc_name
      }
    end
  end

  def text_payload
    {
      type: 'text',
      text: canned_response.content,
      file: nil,
      doc_name: nil
    }
  end

  def attachment_message_type(attachment)
    content_type = attachment.content_type.to_s

    return 'image' if content_type.start_with?('image/')
    return 'video' if content_type.start_with?('video/')
    return 'audio' if content_type.start_with?('audio/')

    'document'
  end

  def update_canned_response_metadata!(api_channel, response)
    quick_reply_id = extract_quick_reply_id(response) || canned_response.uazapi_quick_reply_id(api_channel)
    payload = media_payload

    canned_response.update_uazapi_metadata!(
      channel: api_channel,
      quick_reply_id: quick_reply_id,
      message_type: payload[:type],
      on_whatsapp: false,
      remote_file_url: canned_response.attachments.attached? ? nil : payload[:file],
      remote_doc_name: canned_response.attachments.attached? ? nil : payload[:doc_name],
      remote_content_type: canned_response.attachments.attached? ? nil : canned_response.uazapi_remote_content_type
    )
  end

  def extract_quick_reply_id(response)
    [
      response['id'],
      response.dig('data', 'id'),
      response.dig('quickReply', 'id'),
      response.dig('message', 'id')
    ].compact.first
  end

  def attachment_file_reference(attachment)
    ActiveStorage::Current.url_options = Rails.application.routes.default_url_options if ActiveStorage::Current.url_options.blank?
    url_for(attachment)
  end
end