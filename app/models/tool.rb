class Tool < ApplicationRecord
  belongs_to :window

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }

  rails_admin do
    object_label_method do
      "#{name} - £#{price}"
    end
  end
end
