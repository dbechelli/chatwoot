# frozen_string_literal: true

json.id @group_info[:id]
json.name @group_info[:name]
json.participant_count @group_info[:participant_count]
json.members @group_info[:members] do |member|
  json.phone_number member.phone_number
  json.name member.name
  json.is_admin member.is_admin
  json.joined_at member.joined_at
end
