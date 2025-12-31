# frozen_string_literal: true

class WhatsappGroupService
  pattr_initialize [:conversation!]

  def update_name(new_name)
    raise ArgumentError, 'Conversation is not a WhatsApp group' unless conversation.whatsapp_group?

    provider_service.update_group_name(group_id, new_name)
    update_group_metadata(name: new_name)
  end

  def update_description(new_description)
    raise ArgumentError, 'Conversation is not a WhatsApp group' unless conversation.whatsapp_group?

    provider_service.update_group_description(group_id, new_description)
    update_group_metadata(description: new_description)
  end

  def add_member(phone_number, name: nil)
    raise ArgumentError, 'Conversation is not a WhatsApp group' unless conversation.whatsapp_group?

    provider_service.add_group_participant(group_id, phone_number)
    conversation.add_whatsapp_group_member(phone_number, name: name)
  end

  def remove_member(phone_number)
    raise ArgumentError, 'Conversation is not a WhatsApp group' unless conversation.whatsapp_group?

    provider_service.remove_group_participant(group_id, phone_number)
    member = conversation.whatsapp_group_members.find_by(phone_number: phone_number)
    member&.destroy
  end

  def promote_admin(phone_number)
    raise ArgumentError, 'Conversation is not a WhatsApp group' unless conversation.whatsapp_group?

    provider_service.promote_group_admin(group_id, phone_number)
    member = conversation.whatsapp_group_members.find_by(phone_number: phone_number)
    member&.update!(is_admin: true)
  end

  def demote_admin(phone_number)
    raise ArgumentError, 'Conversation is not a WhatsApp group' unless conversation.whatsapp_group?

    provider_service.demote_group_admin(group_id, phone_number)
    member = conversation.whatsapp_group_members.find_by(phone_number: phone_number)
    member&.update!(is_admin: false)
  end

  def sync_members
    raise ArgumentError, 'Conversation is not a WhatsApp group' unless conversation.whatsapp_group?

    group_info = provider_service.get_group_info(group_id)
    return unless group_info[:participants]

    # Update group metadata
    update_group_metadata(
      name: group_info[:name],
      description: group_info[:description],
      participant_count: group_info[:participants].size
    )

    # Sync members
    sync_members_from_provider(group_info[:participants])
  end

  private

  def group_id
    conversation.whatsapp_group_id
  end

  def provider_service
    @provider_service ||= begin
      inbox = conversation.inbox
      channel = inbox.channel

      case channel.provider
      when 'zapi'
        Whatsapp::Providers::WhatsappZapiService.new(whatsapp_channel: channel)
      when 'baileys'
        Whatsapp::Providers::WhatsappBaileysService.new(whatsapp_channel: channel)
      else
        raise NotImplementedError, "Provider #{channel.provider} does not support group operations"
      end
    end
  end

  def update_group_metadata(attributes)
    current_attrs = conversation.additional_attributes || {}
    current_attrs['whatsapp_group_name'] = attributes[:name] if attributes[:name]
    current_attrs['whatsapp_group_description'] = attributes[:description] if attributes[:description]
    current_attrs['whatsapp_group_participant_count'] = attributes[:participant_count] if attributes[:participant_count]
    conversation.update!(additional_attributes: current_attrs)
  end

  def sync_members_from_provider(participants)
    # Get existing member phone numbers
    existing_members = conversation.whatsapp_group_members.pluck(:phone_number)

    # Add or update members from provider
    participants.each do |participant|
      phone = participant[:id]
      conversation.add_whatsapp_group_member(
        phone,
        name: participant[:name],
        is_admin: participant[:isAdmin] || participant[:isSuperAdmin]
      )
    end

    # Remove members that are no longer in the group
    provider_phones = participants.map { |p| p[:id] }
    removed_members = existing_members - provider_phones
    removed_members.each do |phone|
      member = conversation.whatsapp_group_members.find_by(phone_number: phone)
      member&.destroy
    end
  end
end
