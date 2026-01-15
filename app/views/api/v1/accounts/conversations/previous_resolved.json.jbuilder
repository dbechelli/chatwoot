json.conversations do
  json.array! @previous_conversations do |conversation|
    json.id conversation.id
    json.display_id conversation.display_id
    json.created_at conversation.created_at.to_i
    json.updated_at conversation.updated_at.to_i
    json.status conversation.status
  end
end

json.messages do
  json.array! @messages do |message|
    json.partial! 'api/v1/models/message', message: message
  end
end
