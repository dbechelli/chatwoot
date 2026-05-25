class AddAdditionalAttributesToCannedResponses < ActiveRecord::Migration[7.0]
  def change
    add_column :canned_responses, :additional_attributes, :jsonb, default: {}, null: false
  end
end