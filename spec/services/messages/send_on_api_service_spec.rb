require 'rails_helper'

describe Messages::SendOnApiService do
  describe '#perform' do
    let(:channel_api) { create(:channel_api, account: account, additional_attributes: additional_attributes) }
    let(:account) { create(:account) }
    let(:contact) { create(:contact, account: account, phone_number: '+5511999999999') }
    let(:contact_inbox) { create(:contact_inbox, inbox: channel_api.inbox, contact: contact, source_id: '5511999999999') }
    let(:conversation) { create(:conversation, inbox: channel_api.inbox, account: account, contact: contact, contact_inbox: contact_inbox) }

    context 'when UAZAPI direct delivery is configured' do
      let(:additional_attributes) do
        {
          provider: 'uazapi',
          uazapi_base_url: 'https://demo.uazapi.com',
          uazapi_token: 'secret-token'
        }
      end

      it 'sends the message through UAZAPI and stores the source_id' do
        message = create(:message, message_type: :outgoing, content: 'teste', conversation: conversation, inbox: channel_api.inbox, account: account)

        stub_request(:post, 'https://demo.uazapi.com/send/text')
          .with(
            headers: {
              'Accept' => 'application/json',
              'Content-Type' => 'application/json',
              'Token' => 'secret-token'
            },
            body: {
              number: '5511999999999',
              text: 'teste',
              async: true,
              track_source: 'chatwoot',
              track_id: message.id.to_s
            }
          )
          .to_return(status: 200, body: { messageId: 'uazapi-msg-1' }.to_json, headers: { 'Content-Type' => 'application/json' })

        described_class.new(message: message).perform

        expect(message.reload.source_id).to eq('uazapi-msg-1')
        expect(message.reload.status).to eq('delivered')
      end

      it 'sends a single attachment through the UAZAPI media endpoint and stores the source_id' do
        message = create(:message, message_type: :outgoing, content: 'arquivo', conversation: conversation, inbox: channel_api.inbox, account: account)
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
              text: 'arquivo',
              mimetype: 'image/png',
              async: true,
              track_source: 'chatwoot',
              track_id: message.id.to_s
            }
          )
          .to_return(status: 200, body: { id: 'uazapi-media-1' }.to_json, headers: { 'Content-Type' => 'application/json' })

        described_class.new(message: message).perform

        expect(message.reload.source_id).to eq('uazapi-media-1')
        expect(message.reload.status).to eq('delivered')
      end

      it 'sends document attachments with docName and mimetype' do
        message = create(:message, message_type: :outgoing, content: 'segue o pdf', conversation: conversation, inbox: channel_api.inbox, account: account)
        attachment = message.attachments.build(account_id: message.account_id, file_type: :file)
        attachment.file.attach(io: StringIO.new('%PDF-1.4'), filename: 'contrato.pdf', content_type: 'application/pdf')
        message.save!
        message.attachments.load
        allow(message.attachments.first).to receive(:download_url).and_return('https://files.example.com/contrato.pdf')

        stub_request(:post, 'https://demo.uazapi.com/send/media')
          .with(
            headers: {
              'Accept' => 'application/json',
              'Content-Type' => 'application/json',
              'Token' => 'secret-token'
            },
            body: {
              number: '5511999999999',
              type: 'document',
              file: 'https://files.example.com/contrato.pdf',
              text: 'segue o pdf',
              docName: 'contrato.pdf',
              mimetype: 'application/pdf',
              async: true,
              track_source: 'chatwoot',
              track_id: message.id.to_s
            }
          )
          .to_return(status: 200, body: { id: 'uazapi-doc-1' }.to_json, headers: { 'Content-Type' => 'application/json' })

        described_class.new(message: message).perform

        expect(message.reload.source_id).to eq('uazapi-doc-1')
        expect(message.reload.status).to eq('delivered')
      end

      it 'marks the message as failed when there are multiple attachments' do
        message = create(:message, message_type: :outgoing, content: 'arquivos', conversation: conversation, inbox: channel_api.inbox, account: account)

        first_attachment = message.attachments.build(account_id: message.account_id, file_type: :image)
        first_attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar-1.png', content_type: 'image/png')

        second_attachment = message.attachments.build(account_id: message.account_id, file_type: :image)
        second_attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar-2.png', content_type: 'image/png')

        message.save!

        described_class.new(message: message).perform

        expect(message.reload.status).to eq('failed')
        expect(message.reload.external_error).to eq('Sending multiple attachments in a single UAZAPI message is not supported.')
      end
    end

    context 'when UAZAPI direct delivery is not configured' do
      let(:additional_attributes) { {} }

      it 'falls back to the existing API inbox delivery service' do
        message = create(:message, message_type: :outgoing, content: 'teste', conversation: conversation, inbox: channel_api.inbox, account: account)
        fallback_service = instance_double(Messages::SendEmailNotificationService, perform: true)

        allow(Messages::SendEmailNotificationService).to receive(:new).with(message: message).and_return(fallback_service)

        described_class.new(message: message).perform

        expect(Messages::SendEmailNotificationService).to have_received(:new).with(message: message)
      end
    end
  end
end
