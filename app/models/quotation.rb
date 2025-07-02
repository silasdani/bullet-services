class Quotation < ApplicationRecord
  belongs_to :user
  has_many_attached :images

  enum :status, pending: 0, approved: 1, rejected: 2, completed: 3

  validates :address, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true

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
