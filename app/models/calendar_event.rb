class CalendarEvent < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :title, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  scope :between, ->(start_time, end_time) { where('start_time >= ? AND end_time <= ?', start_time, end_time) }
end
