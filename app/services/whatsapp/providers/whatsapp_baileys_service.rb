class Whatsapp::Providers::WhatsappBaileysService < Whatsapp::Providers::BaseService # rubocop:disable Metrics/ClassLength
  include BaileysHelper

  class MessageContentTypeNotSupported < StandardError; end
  class ProviderUnavailableError < StandardError; end

  DEFAULT_CLIENT_NAME = ENV.fetch('BAILEYS_PROVIDER_DEFAULT_CLIENT_NAME', nil)
  DEFAULT_URL = ENV.fetch('BAILEYS_PROVIDER_DEFAULT_URL', nil)
  DEFAULT_API_KEY = ENV.fetch('BAILEYS_PROVIDER_DEFAULT_API_KEY', nil)

  def self.status
    if DEFAULT_URL.blank? || DEFAULT_API_KEY.blank?
      raise ProviderUnavailableError, 'Missing BAILEYS_PROVIDER_DEFAULT_URL or BAILEYS_PROVIDER_DEFAULT_API_KEY setup'
    end

    response = HTTParty.get(
      "#{DEFAULT_URL}/status",
      headers: { 'x-api-key' => DEFAULT_API_KEY }
    )

    unless response.success?
      Rails.logger.error response.body
      raise ProviderUnavailableError, 'Baileys API is unavailable'
    end

    response.parsed_response.deep_symbolize_keys
  rescue ProviderUnavailableError
    raise
  rescue StandardError => e
    Rails.logger.error e.message
    raise ProviderUnavailableError, 'Baileys API is unavailable'
  end

  def setup_channel_provider
    response = HTTParty.post(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}",
      headers: api_headers,
      body: {
        clientName: DEFAULT_CLIENT_NAME,
        webhookUrl: whatsapp_channel.inbox.callback_webhook_url,
        webhookVerifyToken: whatsapp_channel.provider_config['webhook_verify_token'],
        # TODO: Remove on Baileys v2, default will be false
        includeMedia: false
      }.compact.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def disconnect_channel_provider
    response = HTTParty.delete(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}",
      headers: api_headers
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def send_message(recipient_id, message)
    @message = message
    @recipient_id = recipient_id

    if @message.content_attributes[:is_reaction]
      @message_content = reaction_message_content
    elsif @message.attachments.present?
      @message_content = attachment_message_content
    elsif @message.outgoing_content.present?
      @message_content = { text: @message.outgoing_content }
    else
      @message.update!(is_unsupported: true)
      return
    end

    send_message_request
  end

  def send_template(phone_number, template_info); end

  def sync_templates; end

  def media_url(media_id)
    "#{provider_url}/media/#{media_id}"
  end

  def api_headers
    { 'x-api-key' => api_key, 'Content-Type' => 'application/json' }
  end

  def validate_provider_config?
    response = HTTParty.get(
      "#{provider_url}/status/auth",
      headers: api_headers
    )

    process_response(response)
  end

  def toggle_typing_status(typing_status, recipient_id:, **)
    @recipient_id = recipient_id
    status_map = {
      Events::Types::CONVERSATION_TYPING_ON => 'composing',
      Events::Types::CONVERSATION_RECORDING => 'recording',
      Events::Types::CONVERSATION_TYPING_OFF => 'paused'
    }

    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/presence",
      headers: api_headers,
      body: {
        toJid: remote_jid,
        type: status_map[typing_status]
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def update_presence(status)
    status_map = {
      'online' => 'available',
      'offline' => 'unavailable',
      'busy' => 'unavailable'
    }

    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/presence",
      headers: api_headers,
      body: {
        type: status_map[status]
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def read_messages(messages, recipient_id:, **)
    @recipient_id = recipient_id

    response = HTTParty.post(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/read-messages",
      headers: api_headers,
      body: {
        keys: messages.map do |message|
          {
            id: message.source_id,
            remoteJid: remote_jid,
            fromMe: message.message_type == 'outgoing'
          }
        end
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def unread_message(recipient_id, message) # rubocop:disable Metrics/MethodLength
    @recipient_id = recipient_id

    response = HTTParty.post(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/chat-modify",
      headers: api_headers,
      body: {
        jid: remote_jid,
        mod: {
          markRead: false,
          lastMessages: [{
            key: {
              id: message.source_id,
              remoteJid: remote_jid,
              fromMe: message.message_type == 'outgoing'
            },
            messageTimestamp: message.content_attributes[:external_created_at]
          }]
        }
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def received_messages(recipient_id, messages)
    @recipient_id = recipient_id

    response = HTTParty.post(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/send-receipts",
      headers: api_headers,
      body: {
        keys: messages.map do |message|
          {
            id: message.source_id,
            remoteJid: remote_jid,
            fromMe: message.message_type == 'outgoing'
          }
        end
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def get_profile_pic(jid)
    response = HTTParty.get(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/profile-picture-url",
      headers: api_headers,
      query: { jid: jid },
      format: :json
    )

    return nil unless process_response(response)

    response.parsed_response
  end

  def on_whatsapp(recipient_id)
    @recipient_id = recipient_id

    response = HTTParty.post(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/on-whatsapp",
      headers: api_headers,
      body: {
        jids: [remote_jid]
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    response.parsed_response&.first || { 'jid' => remote_jid, 'exists' => false }
  end

  def forward_message(message, destination_jids)
    # Build the WAMessage object from the Chatwoot message
    wa_message = build_wa_message_from_message(message)

    # Convert destination JIDs to WhatsApp format
    formatted_jids = destination_jids.map do |jid|
      jid.ends_with?('@lid') ? jid : "#{jid.delete('+')}@s.whatsapp.net"
    end

    response = HTTParty.post(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/forward-message",
      headers: api_headers,
      body: {
        message: wa_message,
        destinationJids: formatted_jids
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    response.parsed_response.dig('data', 'results')
  end

  private

  def provider_url
    whatsapp_channel.provider_config['provider_url'].presence || DEFAULT_URL
  end

  def api_key
    whatsapp_channel.provider_config['api_key'].presence || DEFAULT_API_KEY
  end

  def reaction_message_content
    reply_to = Message.find(@message.in_reply_to)
    {
      react: { key: { id: reply_to.source_id,
                      remoteJid: remote_jid,
                      fromMe: reply_to.message_type == 'outgoing' },
               text: @message.outgoing_content }
    }
  end

  def attachment_message_content # rubocop:disable Metrics/MethodLength
    attachment = @message.attachments.first
    buffer = attachment_to_base64(attachment)

    content = {
      fileName: attachment.file.filename,
      caption: @message.outgoing_content
    }
    case attachment.file_type
    when 'image'
      content[:image] = buffer
    when 'audio'
      content[:audio] = buffer
      content[:ptt] = attachment.meta&.dig('is_recorded_audio')
    when 'file'
      content[:document] = buffer
      content[:mimetype] = attachment.file.content_type
    when 'sticker'
      content[:sticker] = buffer
    when 'video'
      content[:video] = buffer
    end

    content.compact
  end

  def send_message_request
    response = HTTParty.post(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/send-message",
      headers: api_headers,
      body: {
        jid: remote_jid,
        messageContent: @message_content
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    update_external_created_at(response)
    response.parsed_response.dig('data', 'key', 'id')
  end

  def process_response(response)
    Rails.logger.error response.body unless response.success?
    response.success?
  end

  def remote_jid
    return @recipient_id if @recipient_id.ends_with?('@lid')

    "#{@recipient_id.delete('+')}@s.whatsapp.net"
  end

  def build_wa_message_from_message(message)
    # Build the key object
    source_id = message.source_id || message.id.to_s
    remote_jid = if message.conversation.contact.identifier.ends_with?('@lid')
                   message.conversation.contact.identifier
                 else
                   "#{message.conversation.contact.identifier.delete('+')}@s.whatsapp.net"
                 end

    key = {
      id: source_id,
      remoteJid: remote_jid,
      fromMe: message.message_type == 'outgoing'
    }

    # Build the message content
    message_content = build_message_content_from_message(message)

    {
      key: key,
      message: message_content
    }
  end

  def build_message_content_from_message(message)
    if message.attachments.present?
      # For messages with attachments, we need to include the media reference
      # Note: Baileys will handle downloading the media using the URL
      attachment = message.attachments.first
      case attachment.file_type
      when 'image'
        { imageMessage: { caption: message.content } }
      when 'video'
        { videoMessage: { caption: message.content } }
      when 'audio'
        { audioMessage: {} }
      when 'file', 'sticker'
        { documentMessage: { caption: message.content } }
      else
        { conversation: message.content }
      end
    elsif message.content.present?
      { conversation: message.content }
    else
      { conversation: '' }
    end
  end

  def update_external_created_at(response)
    timestamp = response.parsed_response.dig('data', 'messageTimestamp')
    return unless timestamp

    external_created_at = baileys_extract_message_timestamp(timestamp)
    @message.update!(external_created_at: external_created_at)
  end

  private_class_method def self.with_error_handling(*method_names)
    method_names.each do |method_name|
      original_method = instance_method(method_name)

      define_method("#{method_name}_without_error_handling") do |*args, **kwargs, &block|
        original_method.bind_call(self, *args, **kwargs, &block)
      end

      define_method(method_name) do |*args, **kwargs, &block|
        original_method.bind_call(self, *args, **kwargs, &block)
      rescue StandardError => e
        handle_channel_error
        raise e
      end
    end
  end

  def handle_channel_error
    whatsapp_channel.update_provider_connection!(connection: 'close')

    return if @handling_error

    @handling_error = true
    begin
      setup_channel_provider_without_error_handling
    rescue StandardError => e
      Rails.logger.error "Failed to reconnect channel after error: #{e.message}"
    ensure
      @handling_error = false
    end
  end

  # WhatsApp Group Management Methods

  def get_group_info(group_id)
    response = HTTParty.get(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/group-metadata",
      headers: api_headers,
      query: { jid: ensure_group_jid(group_id) }
    )

    raise ProviderUnavailableError unless process_response(response)

    response.parsed_response
  end

  def update_group_name(group_id, new_name)
    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/update-group-subject",
      headers: api_headers,
      body: {
        jid: ensure_group_jid(group_id),
        subject: new_name
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def update_group_description(group_id, new_description)
    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/update-group-description",
      headers: api_headers,
      body: {
        jid: ensure_group_jid(group_id),
        description: new_description
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def add_group_participant(group_id, phone_number)
    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/modify-group-participants",
      headers: api_headers,
      body: {
        jid: ensure_group_jid(group_id),
        participants: [format_phone_to_jid(phone_number)],
        action: 'add'
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def remove_group_participant(group_id, phone_number)
    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/modify-group-participants",
      headers: api_headers,
      body: {
        jid: ensure_group_jid(group_id),
        participants: [format_phone_to_jid(phone_number)],
        action: 'remove'
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def promote_group_admin(group_id, phone_number)
    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/modify-group-participants",
      headers: api_headers,
      body: {
        jid: ensure_group_jid(group_id),
        participants: [format_phone_to_jid(phone_number)],
        action: 'promote'
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def demote_group_admin(group_id, phone_number)
    response = HTTParty.patch(
      "#{provider_url}/connections/#{whatsapp_channel.phone_number}/modify-group-participants",
      headers: api_headers,
      body: {
        jid: ensure_group_jid(group_id),
        participants: [format_phone_to_jid(phone_number)],
        action: 'demote'
      }.to_json
    )

    raise ProviderUnavailableError unless process_response(response)

    true
  end

  def ensure_group_jid(group_id)
    return group_id if group_id.ends_with?('@g.us')

    "#{group_id}@g.us"
  end

  def format_phone_to_jid(phone_number)
    clean_phone = phone_number.delete('+')
    "#{clean_phone}@s.whatsapp.net"
  end

  with_error_handling :setup_channel_provider,
                      :disconnect_channel_provider,
                      :send_message,
                      :toggle_typing_status,
                      :update_presence,
                      :read_messages,
                      :unread_message,
                      :received_messages,
                      :on_whatsapp,
                      :get_group_info,
                      :update_group_name,
                      :update_group_description,
                      :add_group_participant,
                      :remove_group_participant,
                      :promote_group_admin,
                      :demote_group_admin
end
