# frozen_string_literal: true

class AddWhatsappGroupSupport < ActiveRecord::Migration[7.0]
  def change
    # Adicionar flag para identificar contatos de grupo
    add_column :contacts, :is_whatsapp_group, :boolean, default: false
    add_index :contacts, :is_whatsapp_group

    # Criar tabela para membros de grupo WhatsApp
    create_table :whatsapp_group_members do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :phone_number, null: false
      t.string :name
      t.boolean :is_admin, default: false
      t.datetime :joined_at
      t.timestamps
    end

    add_index :whatsapp_group_members, [:conversation_id, :phone_number],
              unique: true,
              name: 'index_group_members_on_conversation_and_phone'
  end
end
