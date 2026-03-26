require 'rails_helper'

RSpec.describe CannedResponses::SyncToUazapiService do
  describe '#perform!' do
    let(:account) { create(:account) }
    let!(:channel_api) do
      create(
        :channel_api,
        account: account,
        additional_attributes: {
          provider: 'uazapi',
          uazapi_base_url: 'https://demo.uazapi.com',
          uazapi_token: 'secret-token'
        }
      )
    end
    let(:canned_response) { create(:canned_response, account: account, content: 'arquivo pronto', short_code: 'arquivo') }

    it 'sends attachment url instead of downloading the blob' do
      canned_response.attachments.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'avatar.png',
        content_type: 'image/png'
      )

      service = described_class.new(canned_response: canned_response)
      allow(service).to receive(:attachment_file_reference).and_return('https://files.example.com/avatar.png')

      stub_request(:post, 'https://demo.uazapi.com/quickreply/edit')
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'Token' => 'secret-token'
          },
          body: {
            shortCut: 'arquivo',
            type: 'image',
            text: 'arquivo pronto',
            file: 'https://files.example.com/avatar.png',
            docName: 'avatar.png'
          }
        )
        .to_return(status: 200, body: { id: 'qr-media-1' }.to_json, headers: { 'Content-Type' => 'application/json' })

      expect { service.perform! }.not_to raise_error
      expect(canned_response.reload.uazapi_quick_reply_id(channel_api)).to eq('qr-media-1')
    end
  end
end