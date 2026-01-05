class Whatsapp::SyncGroupsService
  def initialize(inbox)
    @inbox = inbox
    @channel = inbox.channel
  end

  def perform
    return unless @channel.is_a?(Channel::Whatsapp)
    
    # Only for Baileys for now, as other providers might have different APIs
    # But the user context implies Baileys/Evolution
    service = @channel.provider_service
    return unless service.class.name == 'Whatsapp::Providers::WhatsappBaileysService'

    groups = service.fetch_all_groups
    
    # Ensure groups is an array
    return unless groups.is_a?(Array)

    groups.each do |group|
      process_group(group)
    end
  end

  private

  def process_group(group)
    group_jid = group['id']
    group_name = group['subject']
    
    return if group_jid.blank?

    # Ensure contact exists
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: group_jid,
      inbox: @inbox,
      contact_attributes: {
        name: group_name,
        identifier: group_jid,
        is_whatsapp_group: true
      }
    ).perform

    contact = contact_inbox.contact
    
    # Ensure conversation exists
    # We want to ensure a conversation exists so it shows up in the sidebar.
    # If there is no open conversation, create one.
    conversation = contact_inbox.conversations.where.not(status: :resolved).last
    
    unless conversation
      conversation = ::Conversation.create!(
        account_id: @inbox.account_id,
        inbox_id: @inbox.id,
        contact_id: contact.id,
        contact_inbox_id: contact_inbox.id
      )
    end
    
    # Update contact name if it changed
    if contact.name != group_name
      contact.update(name: group_name)
    end
  end
end
