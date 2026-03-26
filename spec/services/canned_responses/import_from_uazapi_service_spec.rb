require 'rails_helper'

RSpec.describe CannedResponses::ImportFromUazapiService do
  describe '#perform' do
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

    it 'imports quick replies from UAZAPI into canned responses' do
      stub_request(:get, 'https://demo.uazapi.com/quickreply/list')
        .with(
          headers: {
            'Accept' => 'application/json',
            'Token' => 'secret-token'
          }
        )
        .to_return(
          status: 200,
          body: {
            data: [
              {
                id: 'qr-1',
                shortCut: 'welcome',
                text: 'Hello there',
                type: 'text',
                onWhatsApp: false
              }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      described_class.new(account: account).perform

      canned_response = account.canned_responses.find_by(short_code: 'welcome')
      expect(canned_response.content).to eq('Hello there')
      expect(canned_response.uazapi_quick_reply_id(channel_api)).to eq('qr-1')
    end
  end
end