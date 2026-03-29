# frozen_string_literal: true

json.enabled @kanban_config['enabled']
json.boards @kanban_config['boards'] do |board|
  json.id board['id']
  json.name board['name']
  json.description board['description']
  json.customAttributeKey board['customAttributeKey']
  json.valueAttributeKey board['valueAttributeKey']
  json.isDefault board['isDefault']
  json.webhook_url board['webhook_url']
  json.enable_round_robin board['enable_round_robin']
  json.auto_assign_stage_id board['auto_assign_stage_id']
  json.agent_ids board['agent_ids'] || []
  json.visible_attributes board['visible_attributes'] || []
  json.auto_assign_inboxes board['auto_assign_inboxes'] || []
  json.stages board['stages'] do |stage|
    json.id stage['id']
    json.name stage['name']
    json.color stage['color']
    json.order stage['order']
    json.wipLimit stage['wipLimit']
  end
end
