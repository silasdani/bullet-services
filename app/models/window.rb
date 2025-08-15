class Window < ApplicationRecord
  belongs_to :window_schedule_repair
  has_one_attached :image

  validates :location, presence: true
  validates :image, presence: true
end
