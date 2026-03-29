require 'rails_helper'

RSpec.describe 'Kanban Settings API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/kanban_settings' do
    it 'returns the kanban configuration for an authenticated agent' do
      get "/api/v1/accounts/#{account.id}/kanban_settings",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('enabled', 'boards')
    end

    it 'returns the default configuration when the kanban schema is not ready' do
      allow_any_instance_of(Account).to receive(:kanban_schema_ready?).and_return(false)

      get "/api/v1/accounts/#{account.id}/kanban_settings",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['boards']).to be_an(Array)
    end

    it 'returns the advanced board fields in the response payload' do
      allow_any_instance_of(Account).to receive(:kanban_configuration).and_return(
        {
          'enabled' => true,
          'boards' => [
            {
              'id' => 'support',
              'name' => 'Support',
              'description' => 'Support pipeline',
              'customAttributeKey' => 'support_status',
              'valueAttributeKey' => 'deal_value',
              'isDefault' => true,
              'webhook_url' => 'https://example.com/webhook',
              'enable_round_robin' => true,
              'auto_assign_stage_id' => 'new_ticket',
              'agent_ids' => [administrator.id],
              'visible_attributes' => ['company'],
              'auto_assign_inboxes' => [1],
              'stages' => [
                {
                  'id' => 'new_ticket',
                  'name' => 'Novo Ticket',
                  'color' => '#60a5fa',
                  'order' => 1,
                  'wipLimit' => nil
                }
              ]
            }
          ]
        }
      )

      get "/api/v1/accounts/#{account.id}/kanban_settings",
          headers: agent.create_new_auth_token,
          as: :json

      board = response.parsed_body['boards'].first
      expect(board['webhook_url']).to eq('https://example.com/webhook')
      expect(board['enable_round_robin']).to eq(true)
      expect(board['agent_ids']).to eq([administrator.id])
      expect(board['visible_attributes']).to eq(['company'])
      expect(board['auto_assign_inboxes']).to eq([1])
    end
  end

  describe 'POST /api/v1/accounts/:account_id/kanban_settings/boards' do
    let(:payload) do
      {
        board: {
          name: 'Support Funnel',
          description: 'Track support work from intake to resolution',
          customAttributeKey: 'support_funnel_status',
          valueAttributeKey: 'deal_value',
          isDefault: false,
          webhook_url: '',
          enable_round_robin: false,
          auto_assign_stage_id: '',
          agent_ids: [],
          visible_attributes: [],
          auto_assign_inboxes: [],
          stages: [
            {
              id: 'new_ticket',
              name: 'Novo Ticket',
              color: '#60a5fa',
              order: 1,
              wipLimit: nil
            }
          ]
        }
      }
    end

    it 'creates a board for an authenticated administrator' do
      expect do
        post "/api/v1/accounts/#{account.id}/kanban_settings/boards",
             headers: administrator.create_new_auth_token,
             params: payload,
             as: :json
      end.to change { account.reload.kanban_boards.count }.by(1)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['name']).to eq('Support Funnel')
      expect(response.parsed_body['customAttributeKey']).to eq('support_funnel_status')
    end

    it 'creates a board even when the account has invalid unrelated settings' do
      account.update_column(:settings, { 'reporting_timezone' => 'Invalid/Timezone' })

      expect do
        post "/api/v1/accounts/#{account.id}/kanban_settings/boards",
             headers: administrator.create_new_auth_token,
             params: payload,
             as: :json
      end.to change { account.reload.kanban_boards.count }.by(1)

      expect(response).to have_http_status(:success)
    end

    it 'rejects an authenticated non-administrator' do
      post "/api/v1/accounts/#{account.id}/kanban_settings/boards",
           headers: agent.create_new_auth_token,
           params: payload,
           as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'persists the board in settings when the kanban schema is not ready' do
      allow_any_instance_of(Account).to receive(:kanban_schema_ready?).and_return(false)

      expect do
        post "/api/v1/accounts/#{account.id}/kanban_settings/boards",
             headers: administrator.create_new_auth_token,
             params: payload,
             as: :json
      end.to change {
        account.reload.settings.fetch('kanban_config', {}).fetch('boards', []).count
      }.by(1)

      expect(response).to have_http_status(:success)
    end
  end
end