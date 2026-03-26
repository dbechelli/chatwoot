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

  def edit_message(message, _new_content, original_content: nil, conversation: nil)
    return if webhook_url.blank?

    payload = message.webhook_data.merge(
      event: 'message_updated',
      changed_attributes: [
        { 'content' => { previous_value: original_content, current_value: message.content } },
        {
          'content_attributes' => {
            previous_value: { 'is_edited' => false, 'previous_content' => nil },
            current_value: { 'is_edited' => true, 'previous_content' => original_content }
          }
        }
      ]
    )
    payload[:conversation] = conversation.webhook_data if conversation.present?

    Webhooks::Trigger.execute(webhook_url, payload, :account_webhook, delivery_id: SecureRandom.uuid)
  end

  private

  def ensure_valid_agent_reply_time_window
    return if additional_attributes['agent_reply_time_window'].blank?
    return if additional_attributes['agent_reply_time_window'].to_i.positive?

    errors.add(:agent_reply_time_window, 'agent_reply_time_window must be greater than 0')
  end
end
