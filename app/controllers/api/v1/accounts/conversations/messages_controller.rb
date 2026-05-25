class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  include Events::Types

  before_action :set_message, only: [:update, :destroy, :retry, :translate, :forward]
  before_action :ensure_api_inbox, only: :update

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform

    trigger_typing_event(CONVERSATION_TYPING_OFF)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    update_message_status
    update_api_inbox_message_metadata
    @message = message.reload
  end

  def destroy
    delete_message_on_channel
    @message = message
    @message.destroy!
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def retry
    return if message.blank?
    return head :unprocessable_entity unless message.failed? && (message.outgoing? || message.template?)

    service = Messages::StatusUpdateService.new(message, 'sent')
    service.perform
    message.update!(content_attributes: {}, source_id: nil)
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  end

  def forward
    contact_ids = forward_params[:contact_ids]
    return render json: { error: I18n.t('errors.forward.no_contacts') }, status: :unprocessable_entity if contact_ids.blank?

    channel = @conversation.inbox.channel
    if channel.is_a?(Channel::Whatsapp) && channel.provider == 'baileys'
      return forward_on_baileys(contact_ids)
    end

    if @conversation.inbox.api? && channel.try(:uazapi_enabled?)
      results = Messages::ForwardOnApiService.new(message: @message, contact_ids: contact_ids, user: Current.user).perform
      return render json: { results: results }
    end

    render json: { error: I18n.t('errors.forward.unsupported_channel') }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "Forward error: #{e.class.name} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :internal_server_error
  end

  def edit_content
    new_content = params[:content]
    return render json: { error: 'Content is required' }, status: :unprocessable_entity if new_content.blank?
    return render json: { error: 'Content exceeds maximum length' }, status: :unprocessable_entity if new_content.length > 150_000
    return render json: { error: 'Only outgoing messages can be edited' }, status: :forbidden unless message.outgoing?

    original_content = message.content
    message.skip_api_inbox_webhook_dispatch = @conversation.inbox.api? && @conversation.inbox.channel.try(:uazapi_enabled?)
    # Only save previous_content on first edit to preserve the original message
    previous_content_to_save = message.is_edited ? message.previous_content : original_content
    message.update!(content: new_content, is_edited: true, previous_content: previous_content_to_save)

    edit_message_on_channel(new_content, original_content)

    @message = message.reload
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  ensure
    message.skip_api_inbox_webhook_dispatch = false
  end

  private

  def forward_on_baileys(contact_ids)
    if @message.source_id.blank?
      Rails.logger.warn "Forward: Message #{@message.id} missing source_id. Cannot forward."
      return render json: { error: I18n.t('errors.forward.missing_source_id') }, status: :unprocessable_entity
    end

    # Get contacts and their identifiers
    contacts = Current.account.contacts.where(id: contact_ids)
    Rails.logger.info "Forward: Found #{contacts.count} contacts for IDs: #{contact_ids.inspect}"

    destination_jids = contacts.map(&:identifier).compact
    Rails.logger.info "Forward: Destination JIDs: #{destination_jids.inspect}"

    return render json: { error: I18n.t('errors.forward.no_valid_contacts') }, status: :unprocessable_entity if destination_jids.empty?

    # Forward the message using the Baileys service
    Rails.logger.info "Forward: Message ID: #{@message.id}, Content: #{@message.content}"
    channel = @conversation.inbox.channel
    service = Whatsapp::Providers::WhatsappBaileysService.new(whatsapp_channel: channel)
    results = service.forward_message(@message, destination_jids)

    Rails.logger.info "Forward: Results: #{results.inspect}"

    render json: { results: results }
  end

  def set_message
    @message = @conversation.messages.find(params[:id])
  end

  def message
    @message ||= @conversation.messages.find(params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error, :content, :source_id)
  end

  def forward_params
    params.permit(contact_ids: [])
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  def update_message_status
    return if permitted_params[:status].blank?

    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
  end

  def update_api_inbox_message_metadata
    return unless params.key?(:source_id)

    previous_source_id = message.source_id
    message.update!(source_id: permitted_params[:source_id])
    sync_pending_uazapi_edit(previous_source_id)
  end

  def delete_message_on_channel
    channel = @conversation.inbox.channel
    return unless channel.respond_to?(:delete_message)
    return if message.source_id.blank?

    channel.delete_message(message, conversation: @conversation)
  rescue StandardError => e
    Rails.logger.error "Failed to delete message on channel: #{e.message}"
    raise e if @conversation.inbox.api? && channel.try(:uazapi_enabled?)
  end

  def edit_message_on_channel(new_content, original_content)
    return unless @conversation.inbox.channel.respond_to?(:edit_message)
    return if message.source_id.blank?

    @conversation.inbox.channel.edit_message(message, new_content, original_content: original_content, conversation: @conversation)
  rescue StandardError => e
    Rails.logger.error "Failed to edit message on channel: #{e.message}"
    was_already_edited = message.previous_content != original_content
    if was_already_edited
      message.update!(content: original_content)
    else
      message.update!(content: original_content, is_edited: false, previous_content: nil)
    end
    raise e
  end

  def sync_pending_uazapi_edit(previous_source_id)
    channel = @conversation.inbox.channel
    return unless channel.try(:uazapi_enabled?)
    return unless previous_source_id.blank?
    return if message.source_id.blank?
    return unless message.outgoing?
    return unless message.is_edited?
    return if message.previous_content.blank?

    edit_message_on_channel(message.content, message.previous_content)
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end

  def trigger_typing_event(event)
    user = Current.user || @resource
    return unless user.is_a?(User)

    Rails.configuration.dispatcher.dispatch(event, Time.zone.now, conversation: @conversation, user: user, is_private: params[:private])
  end
end
