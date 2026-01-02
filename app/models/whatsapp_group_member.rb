# frozen_string_literal: true

# == Schema Information
#
# Table name: whatsapp_group_members
#
#  id              :bigint           not null, primary key
#  is_admin        :boolean          default(FALSE)
#  joined_at       :datetime
#  name            :string
#  phone_number    :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#
# Indexes
#
#  index_group_members_on_conversation_and_phone  (conversation_id,phone_number) UNIQUE
#  index_whatsapp_group_members_on_conversation_id  (conversation_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#

class WhatsappGroupMember < ApplicationRecord
  belongs_to :conversation

  validates :phone_number, presence: true
  validates :conversation_id, uniqueness: { scope: :phone_number }

  scope :admins, -> { where(is_admin: true) }
  scope :regular_members, -> { where(is_admin: false) }

  def display_name
    name.presence || phone_number
  end
end
