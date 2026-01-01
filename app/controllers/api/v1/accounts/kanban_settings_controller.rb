# frozen_string_literal: true

class Api::V1::Accounts::KanbanSettingsController < Api::V1::Accounts::BaseController
  before_action :check_administrator_authorization, except: [:show]

  # GET /api/v1/accounts/:account_id/kanban_settings
  def show
    @kanban_config = Current.account.kanban_config || default_config
  end

  # PUT /api/v1/accounts/:account_id/kanban_settings
  def update
    Current.account.update!(kanban_config: kanban_params)
    @kanban_config = Current.account.kanban_config
    render :show
  end

  # POST /api/v1/accounts/:account_id/kanban_settings/boards
  def create_board
    board = Current.account.add_kanban_board(board_params)
    render json: board
  end

  # PUT /api/v1/accounts/:account_id/kanban_settings/boards/:id
  def update_board
    board = Current.account.update_kanban_board(params[:id], board_params)

    if board
      render json: board
    else
      render json: { error: 'Board not found' }, status: :not_found
    end
  end

  # DELETE /api/v1/accounts/:account_id/kanban_settings/boards/:id
  def destroy_board
    Current.account.delete_kanban_board(params[:id])
    head :no_content
  end

  private

  def check_administrator_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def kanban_params
    params.require(:kanban_config).permit(
      :enabled,
      boards: [
        :id, :name, :description, :customAttributeKey, :valueAttributeKey, :isDefault,
        { agent_ids: [] },
        stages: [:id, :name, :color, :order, :wipLimit]
      ]
    )
  end

  def board_params
    params.require(:board).permit(
      :name, :description, :customAttributeKey, :valueAttributeKey, :isDefault,
      { agent_ids: [] },
      stages: [:id, :name, :color, :order, :wipLimit]
    )
  end

  def default_config
    {
      'enabled' => false,
      'boards' => [
        {
          'id' => 'default-sales',
          'name' => 'Pipeline de Vendas',
          'description' => 'Pipeline padrão de vendas',
          'stages' => [
            { 'id' => 'lead', 'name' => 'Novo Lead', 'color' => '#3b82f6', 'order' => 1, 'wipLimit' => nil },
            { 'id' => 'qualified', 'name' => 'Qualificado', 'color' => '#8b5cf6', 'order' => 2, 'wipLimit' => 20 },
            { 'id' => 'proposal', 'name' => 'Proposta', 'color' => '#f59e0b', 'order' => 3, 'wipLimit' => 15 },
            { 'id' => 'negotiation', 'name' => 'Negociação', 'color' => '#ec4899', 'order' => 4, 'wipLimit' => 10 },
            { 'id' => 'won', 'name' => 'Ganho', 'color' => '#10b981', 'order' => 5, 'wipLimit' => nil },
            { 'id' => 'lost', 'name' => 'Perdido', 'color' => '#ef4444', 'order' => 6, 'wipLimit' => nil }
          ],
          'customAttributeKey' => 'sales_stage',
          'valueAttributeKey' => 'deal_value',
          'isDefault' => true
        }
      ]
    }
  end
end
