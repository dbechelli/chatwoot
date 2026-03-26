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

  private

  def uazapi_client
    @uazapi_client ||= Uazapi::Client.new(base_url: uazapi_base_url, token: uazapi_token)
  end

  def validate_uazapi_configuration!
    return if uazapi_base_url.present? && uazapi_token.present?

    raise 'UAZAPI is not fully configured for this API inbox'
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
      response.dig('message', 'id'),
      response.dig('data', 'id'),
      response.dig('message', 'key', 'id'),
      response.dig('data', 'message', 'id'),
      response.dig('data', 'key', 'id')
    ]

    candidates.compact.first
  end

  def ensure_valid_agent_reply_time_window
    return if additional_attributes['agent_reply_time_window'].blank?
    return if additional_attributes['agent_reply_time_window'].to_i.positive?

    errors.add(:agent_reply_time_window, 'agent_reply_time_window must be greater than 0')
  end
end
