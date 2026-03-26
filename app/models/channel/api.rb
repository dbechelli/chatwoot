# == Schema Information
#
# Table name: channel_api
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  hmac_mandatory        :boolean          default(FALSE)
#  hmac_token            :string
#  identifier            :string
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#
# Indexes
#
#  index_channel_api_on_hmac_token  (hmac_token) UNIQUE
#  index_channel_api_on_identifier  (identifier) UNIQUE
#

class Channel::Api < ApplicationRecord
  include Channelable

  self.table_name = 'channel_api'
  EDITABLE_ATTRS = [:webhook_url, :hmac_mandatory, { additional_attributes: {} }].freeze

  has_secure_token :identifier
  has_secure_token :hmac_token
  validate :ensure_valid_agent_reply_time_window
  validates :webhook_url, length: { maximum: Limits::URL_LENGTH_LIMIT }

  def name
    'API'
  end

  def send_message(message)
    validate_uazapi_configuration!
    validate_uazapi_message!(message)

    return send_media_message(message) if message.attachments.present?

    response = uazapi_client.send_text_message(
      recipient_id: uazapi_recipient_id(message),
      text: message.outgoing_content,
      quoted_message_id: message.in_reply_to_external_id,
      track_id: message.id.to_s,
      forward: uazapi_forwarded?(message)
    )

    extract_message_id(response)
  end

  def edit_message(message, _new_content, **)
    return unless uazapi_enabled?

    validate_uazapi_configuration!

    response = uazapi_client.edit_message(message_id: message.source_id, text: message.content)
    updated_source_id = extract_message_id(response)
    message.update!(source_id: updated_source_id) if updated_source_id.present? && updated_source_id != message.source_id
  end

  def delete_message(message, **)
    return unless uazapi_enabled?

    validate_uazapi_configuration!

    uazapi_client.delete_message(message_id: message.source_id)
  end

  def uazapi_enabled?
    uazapi_base_url.present? || additional_attributes&.dig('provider') == 'uazapi'
  end

  def uazapi_base_url
    additional_attributes&.dig('uazapi_base_url').presence || derived_uazapi_base_url
  end

  def uazapi_token
    additional_attributes&.dig('uazapi_token').presence
  end

  def uazapi_direct_message_delivery?(message)
    return false unless uazapi_enabled?

    validate_uazapi_message!(message)
    true
  rescue StandardError
    false
  end

  def validate_uazapi_message!(message)
    raise I18n.t('errors.uazapi.message_required') if message.outgoing_content.blank? && message.attachments.blank?
    raise I18n.t('errors.uazapi.multiple_attachments_not_supported') if message.attachments.many?

    return if message.attachments.blank?

    attachment = message.attachments.first
    raise I18n.t('errors.uazapi.unsupported_attachment_type') if uazapi_media_type(attachment).blank?
    raise I18n.t('errors.uazapi.public_url_missing') if uazapi_file_url(attachment).blank?
  end

  private

  def uazapi_client
    @uazapi_client ||= Uazapi::Client.new(base_url: uazapi_base_url, token: uazapi_token)
  end

  def validate_uazapi_configuration!
    return if uazapi_base_url.present? && uazapi_token.present?

    raise I18n.t('errors.uazapi.not_configured')
  end

  def derived_uazapi_base_url
    return if webhook_url.blank?

    uri = URI.parse(webhook_url)
    return unless uri.host&.include?('uazapi.com')

    "#{uri.scheme}://#{uri.host}"
  rescue URI::InvalidURIError
    nil
  end

  def extract_message_id(response)
    candidates = [
      response['id'],
      response['messageId'],
      response.dig('message', 'id'),
      response.dig('message', 'messageId'),
      response.dig('data', 'id'),
      response.dig('data', 'messageId'),
      response.dig('message', 'key', 'id'),
      response.dig('data', 'message', 'id'),
      response.dig('data', 'key', 'id')
    ]

    candidates.compact.first
  end

  def send_media_message(message)
    attachment = message.attachments.first

    response = uazapi_client.send_media_message(
      recipient_id: uazapi_recipient_id(message),
      media_type: uazapi_media_type(attachment),
      file_url: uazapi_file_url(attachment),
      text: message.outgoing_content.presence,
      doc_name: uazapi_doc_name(attachment),
      mime_type: attachment.file.content_type.presence,
      reply_id: message.in_reply_to_external_id,
      track_id: message.id.to_s,
      forward: uazapi_forwarded?(message)
    )

    extract_message_id(response)
  end

  def uazapi_recipient_id(message)
    raw_recipient = [
      message.conversation.contact.phone_number,
      message.conversation.contact.identifier,
      message.conversation.contact_inbox&.source_id
    ].find(&:present?)

    normalized_recipient = raw_recipient.to_s.gsub(/[^\d]/, '')
    return normalized_recipient if normalized_recipient.present?
    return raw_recipient if raw_recipient.present?

    raise I18n.t('errors.uazapi.recipient_missing')
  end

  def uazapi_supported_attachment?(attachment)
    uazapi_media_type(attachment).present? && uazapi_file_url(attachment).present?
  rescue StandardError
    false
  end

  def uazapi_media_type(attachment)
    {
      'image' => 'image',
      'video' => 'video',
      'audio' => 'audio',
      'file' => 'document'
    }[attachment.file_type]
  end

  def uazapi_file_url(attachment)
    return attachment.external_url if attachment.external_url.present?

    attachment.download_url.presence || attachment.file_url.presence
  end

  def uazapi_doc_name(attachment)
    return unless attachment.file_type == 'file'
    return unless attachment.file.attached?

    attachment.file.filename.to_s
  end

  def uazapi_forwarded?(message)
    message.content_attributes.is_a?(Hash) && message.content_attributes['forward'] == true
  end

  def ensure_valid_agent_reply_time_window
    return if additional_attributes['agent_reply_time_window'].blank?
    return if additional_attributes['agent_reply_time_window'].to_i.positive?

    errors.add(:agent_reply_time_window, 'agent_reply_time_window must be greater than 0')
  end
end
