class Whatsapp::SyncGroupsService
  def initialize(inbox)
    @inbox = inbox
    @channel = inbox.channel
  end

  def perform
    return unless @channel.is_a?(Channel::Whatsapp)
    
    # Only for Baileys for now
    service = @channel.provider_service
    return unless service.class.name.include?('WhatsappBaileysService')

    begin
      groups = service.fetch_all_groups
      
      return unless groups.is_a?(Array)

      groups.each do |group|
        process_group(group)
      end
    rescue StandardError => e
      Rails.logger.error "[Whatsapp::SyncGroupsService] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
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
        additional_attributes: { is_whatsapp_group: true }
      }
    ).perform

    return unless contact_inbox

    contact = contact_inbox.contact
    
    return unless contact

    # Ensure conversation exists
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
