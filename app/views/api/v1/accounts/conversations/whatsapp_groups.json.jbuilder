json.meta do
  json.total_count @groups_count
end

json.payload @groups do |conversation|
  json.id conversation.id
  json.display_id conversation.display_id
  json.inbox_id conversation.inbox_id
  json.name conversation.whatsapp_group_name.presence || conversation.contact&.name || conversation.whatsapp_group_id
  json.participant_count conversation.whatsapp_group_participants_count
  json.last_activity_at conversation.last_activity_at.to_i
end
