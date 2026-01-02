# frozen_string_literal: true

class AddKanbanConfigToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :kanban_config, :jsonb, default: {
      'enabled' => false,
      'boards' => []
    }

    # Adicionar índice GIN para queries eficientes no JSONB
    add_index :accounts, :kanban_config, using: :gin
  end
end
