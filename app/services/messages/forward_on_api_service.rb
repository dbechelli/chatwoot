class Messages::ForwardOnApiService
  pattr_initialize [:message!, :contact_ids!, :user!]

  def perform
    validate_message_support!
    raise I18n.t('errors.forward.no_valid_contacts') if contacts.empty?

    contacts.map do |contact|
      forward_to_contact(contact)
    end
  end

  private

  def validate_message_support!
    raise I18n.t('errors.forward.unsupported_message') if message.private?
    raise I18n.t('errors.forward.unsupported_message') if message.outgoing_content.blank? && message.attachments.blank?
  end

  def contacts
    @contacts ||= message.account.contacts.where(id: contact_ids)
  end

  def forward_to_contact(contact)
    contact_inbox = destination_contact_inbox(contact)
    conversation = destination_conversation(contact_inbox)
    forwarded_messages = build_forwarded_messages(conversation)

    {
      contact_id: contact.id,
      conversation_id: conversation.display_id,
      message_ids: forwarded_messages.map(&:id)
    }
  end

  def build_forwarded_messages(conversation)
    return [create_forwarded_message(conversation: conversation, content: message.outgoing_content)] if message.attachments.blank?

    message.attachments.each_with_index.map do |attachment, index|
      create_forwarded_message(
        conversation: conversation,
        content: index.zero? ? message.outgoing_content : nil,
        attachment: attachment
      )
    end
  end

  def create_forwarded_message(conversation:, content:, attachment: nil)
    forwarded_message = conversation.messages.build(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: content,
      content_type: 'text',
      sender: user || message.sender,
      content_attributes: { forward: true }
    )

    clone_attachment(forwarded_message, attachment) if attachment.present?
    forwarded_message.save!
    forwarded_message
  end

  def clone_attachment(forwarded_message, source_attachment)
    attrs = {
      account_id: forwarded_message.account_id,
      file_type: source_attachment.file_type,
      external_url: source_attachment.external_url,
      extension: source_attachment.extension,
      fallback_title: source_attachment.fallback_title,
      coordinates_lat: source_attachment.coordinates_lat,
      coordinates_long: source_attachment.coordinates_long,
      meta: source_attachment.meta&.deep_dup
    }

    attrs[:file] = source_attachment.file.blob.signed_id if source_attachment.file.attached?
    forwarded_message.attachments.build(attrs)
  end

  def destination_contact_inbox(contact)
    inbox.contact_inboxes.where(contact: contact).last ||
      ContactInboxBuilder.new(contact: contact, inbox: inbox, source_id: destination_source_id(contact)).perform
  end

  def destination_conversation(contact_inbox)
    inbox.conversations.where(contact_id: contact_inbox.contact_id).where.not(status: :resolved).last ||
      ConversationBuilder.new(params: ActionController::Parameters.new(status: 'open'), contact_inbox: contact_inbox).perform
  end

  def destination_source_id(contact)
    existing_source_id = inbox.contact_inboxes.where(contact: contact).order(created_at: :desc).pick(:source_id)
    return existing_source_id if existing_source_id.present?

    contact.identifier.presence || contact.phone_number.to_s.gsub(/[^\d]/, '').presence || contact.email.presence || SecureRandom.uuid
  end

  def inbox
    @inbox ||= message.inbox
  end
end