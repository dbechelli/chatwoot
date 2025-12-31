# frozen_string_literal: true

json.enabled @kanban_config['enabled']
json.boards @kanban_config['boards'] do |board|
  json.id board['id']
  json.name board['name']
  json.description board['description']
  json.customAttributeKey board['customAttributeKey']
  json.valueAttributeKey board['valueAttributeKey']
  json.isDefault board['isDefault']
  json.stages board['stages'] do |stage|
    json.id stage['id']
    json.name stage['name']
    json.color stage['color']
    json.order stage['order']
    json.wipLimit stage['wipLimit']
  end
end
