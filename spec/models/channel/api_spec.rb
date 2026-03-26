# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Api do
  # This validation happens in ApplicationRecord
  describe 'length validations' do
    let(:channel_api) { create(:channel_api) }

    context 'when it validates webhook_url length' do
      it 'valid when within limit' do
        channel_api.webhook_url = 'a' * Limits::URL_LENGTH_LIMIT
        expect(channel_api.valid?).to be true
      end

      it 'invalid when crossed the limit' do
        channel_api.webhook_url = 'a' * (Limits::URL_LENGTH_LIMIT + 1)
        channel_api.valid?
        expect(channel_api.errors[:webhook_url]).to include("is too long (maximum is #{Limits::URL_LENGTH_LIMIT} characters)")
      end
    end
  end

  describe '#edit_message' do
    let(:channel_api) do
      create(
        :channel_api,
        additional_attributes: {
          provider: 'uazapi',
          uazapi_base_url: 'https://demo.uazapi.com',
          uazapi_token: 'secret-token'
        }
      )
    end
    let(:message) { create(:message, inbox: channel_api.inbox, account: channel_api.account, source_id: 'uazapi-msg-1', content: 'Novo texto') }

    it 'calls the UAZAPI edit endpoint and syncs the new source_id' do
      stub_request(:post, 'https://demo.uazapi.com/message/edit')
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Token' => 'secret-token'
          },
          body: { id: 'uazapi-msg-1', text: 'Novo texto' }
        )
        .to_return(status: 200, body: { id: 'uazapi-msg-2' }.to_json, headers: { 'Content-Type' => 'application/json' })

      channel_api.edit_message(message, message.content)

      expect(message.reload.source_id).to eq('uazapi-msg-2')
    end
  end

  describe '#send_message' do
    let(:channel_api) do
      create(
        :channel_api,
        additional_attributes: {
          provider: 'uazapi',
          uazapi_base_url: 'https://demo.uazapi.com',
          uazapi_token: 'secret-token'
        }
      )
    end
    let(:contact) { create(:contact, account: channel_api.account, phone_number: '+5511999999999') }
    let(:contact_inbox) { create(:contact_inbox, inbox: channel_api.inbox, contact: contact, source_id: '5511999999999') }
    let(:conversation) { create(:conversation, inbox: channel_api.inbox, account: channel_api.account, contact: contact, contact_inbox: contact_inbox) }

    it 'calls the UAZAPI send text endpoint and returns the provider message id' do
      message = create(:message, inbox: channel_api.inbox, account: channel_api.account, conversation: conversation, content: 'Nova mensagem')

      stub_request(:post, 'https://demo.uazapi.com/message/send-text')
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Token' => 'secret-token'
          },
          body: { phone: '5511999999999', message: 'Nova mensagem' }
        )
        .to_return(status: 200, body: { messageId: 'uazapi-msg-1' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(channel_api.send_message(message)).to eq('uazapi-msg-1')
    end

    it 'calls the UAZAPI send media endpoint for image attachments' do
      message = create(:message, inbox: channel_api.inbox, account: channel_api.account, conversation: conversation, content: 'Veja o anexo')
      attachment = message.attachments.build(account_id: message.account_id, file_type: :image)
      attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      message.save!
      message.attachments.load
      allow(message.attachments.first).to receive(:download_url).and_return('https://files.example.com/avatar.png')

      stub_request(:post, 'https://demo.uazapi.com/send/media')
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Token' => 'secret-token'
          },
          body: {
            number: '5511999999999',
            type: 'image',
            file: 'https://files.example.com/avatar.png',
            text: 'Veja o anexo',
            mimetype: 'image/png',
            async: true,
            track_source: 'chatwoot',
            track_id: message.id.to_s
          }
        )
        .to_return(status: 200, body: { id: 'uazapi-media-1' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(channel_api.send_message(message)).to eq('uazapi-media-1')
    end
  end

  describe '#delete_message' do
    let(:channel_api) do
      create(
        :channel_api,
        additional_attributes: {
          provider: 'uazapi',
          uazapi_base_url: 'https://demo.uazapi.com',
          uazapi_token: 'secret-token'
        }
      )
    end
    let(:message) { create(:message, inbox: channel_api.inbox, account: channel_api.account, source_id: 'uazapi-msg-1') }

    it 'calls the UAZAPI delete endpoint' do
      delete_request = stub_request(:post, 'https://demo.uazapi.com/message/delete')
                       .with(
                         headers: {
                           'Accept' => 'application/json',
                           'Content-Type' => 'application/json',
                           'Token' => 'secret-token'
                         },
                         body: { id: 'uazapi-msg-1' }
                       )
                       .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

      channel_api.delete_message(message)

      expect(delete_request).to have_been_requested
    end
  end
end
