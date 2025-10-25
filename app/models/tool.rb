# frozen_string_literal: true

class Tool < ApplicationRecord
  belongs_to :window

  validates :name, presence: true
  validates :price, presence: true
end
