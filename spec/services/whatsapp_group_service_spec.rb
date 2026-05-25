require 'rails_helper'

describe WhatsappGroupService do
  let!(:account) { create(:account) }
  let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'baileys', account: account) }
  let!(:inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let!(:contact) { create(:contact, account: account, identifier: '123456789@g.us') }
  let!(:conversation) { create(:conversation, inbox: inbox, contact: contact, additional_attributes: { is_whatsapp_group: true, whatsapp_group_id: '123456789' }) }
  
  subject(:service) { described_class.new(conversation: conversation) }
  
  let(:provider_service) { instance_double(Whatsapp::Providers::WhatsappBaileysService) }
  
  before do
    allow(Whatsapp::Providers::WhatsappBaileysService).to receive(:new).with(whatsapp_channel: whatsapp_channel).and_return(provider_service)
  end

  describe '#update_name' do
    it 'calls provider service and updates local metadata' do
      expect(provider_service).to receive(:update_group_name).with('123456789', 'New Name').and_return(true)
      
      service.update_name('New Name')
      
      expect(conversation.reload.additional_attributes['whatsapp_group_name']).to eq('New Name')
    end

    it 'raises error if not a group' do
      conversation.update!(additional_attributes: {})
      # Ensure contact identifier doesn't trigger fallback
      contact.update!(identifier: '123456789')
      
      expect { service.update_name('New Name') }.to raise_error(ArgumentError, 'Conversation is not a WhatsApp group')
    end
  end

  describe '#update_description' do
    it 'calls provider service and updates local metadata' do
      expect(provider_service).to receive(:update_group_description).with('123456789', 'New Desc').and_return(true)
      
      service.update_description('New Desc')
      
      expect(conversation.reload.additional_attributes['whatsapp_group_description']).to eq('New Desc')
    end
  end

  describe '#add_member' do
    it 'calls provider service and adds member locally' do
      expect(provider_service).to receive(:add_group_participant).with('123456789', '5511999999999').and_return(true)
      
      service.add_member('5511999999999', name: 'John Doe')
      
      member = conversation.reload.whatsapp_group_members.find_by(phone_number: '5511999999999')
      expect(member).to be_present
      expect(member.name).to eq('John Doe')
    end
  end

  describe '#remove_member' do
    let!(:member) { conversation.add_whatsapp_group_member('5511999999999', name: 'John Doe') }

    it 'calls provider service and removes member locally' do
      expect(provider_service).to receive(:remove_group_participant).with('123456789', '5511999999999').and_return(true)
      
      service.remove_member('5511999999999')
      
      expect(conversation.reload.whatsapp_group_members.find_by(phone_number: '5511999999999')).to be_nil
    end
  end

  describe '#promote_admin' do
    let!(:member) { conversation.add_whatsapp_group_member('5511999999999', name: 'John Doe') }

    it 'calls provider service and updates member admin status' do
      expect(provider_service).to receive(:promote_group_admin).with('123456789', '5511999999999').and_return(true)
      
      service.promote_admin('5511999999999')
      
      expect(member.reload.is_admin).to be(true)
    end
  end

  describe '#demote_admin' do
    let!(:member) { conversation.add_whatsapp_group_member('5511999999999', name: 'John Doe', is_admin: true) }

    it 'calls provider service and updates member admin status' do
      expect(provider_service).to receive(:demote_group_admin).with('123456789', '5511999999999').and_return(true)
      
      service.demote_admin('5511999999999')
      
      expect(member.reload.is_admin).to be(false)
    end
  end

  describe '#sync_members' do
    before do
      conversation.add_whatsapp_group_member('111', name: 'Old User')
    end

    let(:group_info) do
      {
        subject: 'Synced Name',
        desc: 'Synced Desc',
        participants: [
          { id: '222@s.whatsapp.net', admin: 'admin', notify: 'New Admin' },
          { id: '333@s.whatsapp.net', admin: nil, notify: 'Regular User' }
        ]
      }
    end

    it 'syncs members and metadata from provider' do
      expect(provider_service).to receive(:get_group_info).with('123456789').and_return(group_info)
      
      service.sync_members

      conversation.reload
      expect(conversation.whatsapp_group_name).to eq('Synced Name')
      expect(conversation.additional_attributes['whatsapp_group_description']).to eq('Synced Desc')
      expect(conversation.whatsapp_group_participants_count).to eq(2)
      
      # Check members
      expect(conversation.whatsapp_group_members.count).to eq(2)
      expect(conversation.whatsapp_group_members.find_by(phone_number: '111')).to be_nil # Removed
      
      admin = conversation.whatsapp_group_members.find_by(phone_number: '222')
      expect(admin.is_admin).to be(true)
      expect(admin.name).to eq('New Admin')

      regular = conversation.whatsapp_group_members.find_by(phone_number: '333')
      expect(regular.is_admin).to be(false)
      expect(regular.name).to eq('Regular User')
    end
  end
end
