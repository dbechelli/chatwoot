class CreateCalendarEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :calendar_events do |t|
      t.string :title
      t.text :description
      t.datetime :start_time
      t.datetime :end_time
      t.integer :account_id
      t.integer :user_id

      t.timestamps
    end

    add_index :calendar_events, :account_id
    add_index :calendar_events, :user_id
  end
end
