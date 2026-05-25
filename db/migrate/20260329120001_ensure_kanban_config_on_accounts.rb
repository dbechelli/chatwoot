# frozen_string_literal: true

class EnsureKanbanConfigOnAccounts < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:accounts, :kanban_config)
      add_column :accounts, :kanban_config, :jsonb, default: { 'enabled' => false, 'boards' => [] }, null: false
    end

    add_index :accounts, :kanban_config, using: :gin, if_not_exists: true
  end
end