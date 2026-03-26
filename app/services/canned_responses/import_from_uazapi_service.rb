class CannedResponses::ImportFromUazapiService
  def initialize(account:)
    @account = account
  end

  def perform
    configured_api_channels.each do |api_channel|
      import_from_channel(api_channel)
    end
  end

  private

  attr_reader :account

  def configured_api_channels
    account.api_channels.select do |api_channel|
      api_channel.uazapi_enabled? && api_channel.uazapi_base_url.present? && api_channel.uazapi_token.present?
    end
  end

  def import_from_channel(api_channel)
    api_channel.send(:uazapi_client).list_quick_replies.each do |quick_reply|
      next if quick_reply_short_code(quick_reply).blank?

      canned_response = find_or_initialize_canned_response(api_channel, quick_reply)
      canned_response.short_code = quick_reply_short_code(quick_reply)
      canned_response.content = quick_reply_text(quick_reply)
      canned_response.additional_attributes = merged_attributes(canned_response, api_channel, quick_reply)
      canned_response.save!
    end
  end

  def find_or_initialize_canned_response(api_channel, quick_reply)
    quick_reply_id = quick_reply_id(quick_reply)

    account.canned_responses.find do |canned_response|
      canned_response.uazapi_quick_reply_id(api_channel) == quick_reply_id(quick_reply)
    end ||
      account.canned_responses.find_or_initialize_by(short_code: quick_reply_short_code(quick_reply))
  end

  def merged_attributes(canned_response, api_channel, quick_reply)
    existing_attributes = canned_response.additional_attributes || {}
    quick_reply_ids = (existing_attributes['uazapi_quick_reply_ids'] || {}).merge(api_channel.id.to_s => quick_reply_id(quick_reply))

    existing_attributes.merge(
      'uazapi_quick_reply_id' => quick_reply_id(quick_reply),
      'uazapi_quick_reply_ids' => quick_reply_ids,
      'uazapi_message_type' => quick_reply_type(quick_reply),
      'uazapi_on_whatsapp' => ActiveModel::Type::Boolean.new.cast(quick_reply['onWhatsApp']),
      'uazapi_remote_file_url' => quick_reply['file'].presence,
      'uazapi_remote_doc_name' => quick_reply['docName'].presence,
      'uazapi_remote_content_type' => quick_reply_content_type(quick_reply)
    )
  end

  def quick_reply_id(quick_reply)
    quick_reply['id'].to_s
  end

  def quick_reply_short_code(quick_reply)
    quick_reply['shortCut'].to_s.strip
  end

  def quick_reply_text(quick_reply)
    quick_reply['text'].to_s
  end

  def quick_reply_type(quick_reply)
    quick_reply['type'].presence || 'text'
  end

  def quick_reply_content_type(quick_reply)
    {
      'image' => 'image/*',
      'video' => 'video/*',
      'audio' => 'audio/*',
      'myaudio' => 'audio/*',
      'ptt' => 'audio/*',
      'document' => 'application/octet-stream'
    }[quick_reply_type(quick_reply)]
  end
end