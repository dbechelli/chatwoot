# == Schema Information
#
# Table name: canned_responses
#
#  id         :integer          not null, primary key
#  content    :text
#  short_code :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#

class CannedResponse < ApplicationRecord
  has_many_attached :attachments

  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }
  validate :content_or_attachment_present

  belongs_to :account

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }

  def file_urls
    attachments.map do |attachment|
      {
        id: attachment.id,
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        url: Rails.application.routes.url_helpers.url_for(attachment)
      }
    end
  end

  def canned_files
    return file_urls if attachments.attached?
    return [] if uazapi_remote_file_url.blank?

    [
      {
        id: "uazapi-#{id}",
        filename: uazapi_remote_doc_name.presence || short_code,
        content_type: uazapi_remote_content_type,
        url: uazapi_remote_file_url,
        source: 'uazapi'
      }
    ]
  end

  def uazapi_quick_reply_ids
    normalized_additional_attributes['uazapi_quick_reply_ids'] || {}
  end

  def uazapi_quick_reply_id(channel = nil)
    return uazapi_quick_reply_ids[channel.id.to_s] if channel.present?

    normalized_additional_attributes['uazapi_quick_reply_id'] || uazapi_quick_reply_ids.values.first
  end

  def uazapi_message_type
    normalized_additional_attributes['uazapi_message_type'].presence || 'text'
  end

  def uazapi_remote_file_url
    normalized_additional_attributes['uazapi_remote_file_url'].presence
  end

  def uazapi_remote_doc_name
    normalized_additional_attributes['uazapi_remote_doc_name'].presence
  end

  def uazapi_remote_content_type
    normalized_additional_attributes['uazapi_remote_content_type'].presence
  end

  def uazapi_on_whatsapp?
    normalized_additional_attributes['uazapi_on_whatsapp'] == true
  end

  def update_uazapi_metadata!(channel:, quick_reply_id:, message_type:, on_whatsapp: false, remote_file_url: nil,
                              remote_doc_name: nil, remote_content_type: nil)
    quick_reply_ids = uazapi_quick_reply_ids.merge(channel.id.to_s => quick_reply_id)
    attributes = normalized_additional_attributes.merge(
      'uazapi_quick_reply_id' => quick_reply_id,
      'uazapi_quick_reply_ids' => quick_reply_ids,
      'uazapi_message_type' => message_type,
      'uazapi_on_whatsapp' => on_whatsapp,
      'uazapi_remote_file_url' => remote_file_url,
      'uazapi_remote_doc_name' => remote_doc_name,
      'uazapi_remote_content_type' => remote_content_type
    )

    update!(additional_attributes: attributes)
  end

  def clear_uazapi_metadata!(channel: nil)
    attributes = normalized_additional_attributes.deep_dup
    quick_reply_ids = (attributes['uazapi_quick_reply_ids'] || {}).deep_dup

    if channel.present?
      quick_reply_ids.delete(channel.id.to_s)
    else
      quick_reply_ids = {}
    end

    attributes['uazapi_quick_reply_ids'] = quick_reply_ids
    attributes['uazapi_quick_reply_id'] = quick_reply_ids.values.first
    attributes['uazapi_message_type'] = 'text' if quick_reply_ids.blank?
    attributes['uazapi_on_whatsapp'] = false if quick_reply_ids.blank?
    attributes['uazapi_remote_file_url'] = nil
    attributes['uazapi_remote_doc_name'] = nil
    attributes['uazapi_remote_content_type'] = nil

    update!(additional_attributes: attributes)
  end

  private

  def normalized_additional_attributes
    value = self[:additional_attributes]

    case value
    when Hash
      value.stringify_keys
    when ActionController::Parameters
      value.to_unsafe_h.stringify_keys
    when String
      JSON.parse(value).stringify_keys
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end

  def content_or_attachment_present
    return if content.present? || attachments.attached? || uazapi_remote_file_url.present?

    errors.add(:content, :blank)
  end
end
