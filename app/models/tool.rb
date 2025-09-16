class Tool < ApplicationRecord
  belongs_to :window

  validates :name, presence: true
  validates :price, presence: true

  rails_admin do
    object_label_method do
      "#{name} - £#{price}"
    end
  end
end
