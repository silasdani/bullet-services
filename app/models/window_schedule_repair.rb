class WindowScheduleRepair < ApplicationRecord
  belongs_to :user
  has_many :windows, dependent: :destroy
  has_many_attached :images

  enum :status, pending: 0, approved: 1, rejected: 2, completed: 3

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :address, presence: true
  validates :total_vat_included_price, presence: true, numericality: { greater_than: 0 }

  scope :for_user, ->(user) {
    case user.role
    when 'admin'
      all
    when 'employee'
      where(user: user)
    when 'client'
      where(user: user)
    end
  }
end
