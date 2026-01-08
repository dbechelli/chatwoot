class Whatsapp::SyncGroupsService
  def initialize(inbox)
    @inbox = inbox
    @channel = inbox.channel
  end

  def perform
    return unless @channel.is_a?(Channel::Whatsapp)
    
    service = @channel.provider_service
    return unless service.respond_to?(:fetch_all_groups)

    begin
      groups = service.fetch_all_groups

      # Handle Baileys Map format (jid => metadata) or wrapped responses
      if groups.is_a?(Hash)
        if groups.values.first.is_a?(Hash) && (groups.values.first.key?('id') || groups.values.first.key?('subject'))
          groups = groups.values
        elsif groups['data'].is_a?(Array)
          groups = groups['data']
        elsif groups['groups'].is_a?(Array)
          groups = groups['groups']
        end
      end
      
      unless groups.is_a?(Array)
        Rails.logger.warn "[Whatsapp::SyncGroupsService] Expected Array or Hash of groups, received: #{groups.class}. Content sample: #{groups.inspect[0..200]}"
        return 
      end

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
    
    # Update contact name if it changed, and ensure flag is set
    updates = {}
    updates[:name] = group_name if contact.name != group_name
    updates[:is_whatsapp_group] = true if contact.respond_to?(:is_whatsapp_group?) && !contact.try(:is_whatsapp_group?)
    
    contact.update(updates) if updates.present?
  end
end
