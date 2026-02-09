# frozen_string_literal: true

class Tool < ApplicationRecord
  belongs_to :window

  before_validation :set_default_price, if: -> { name.present? && price.blank? }

  validates :name, presence: true
  validates :price, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[name price window_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[window]
  end

  def self.common_tool_names
    [
      'No Works Required',
      '½ set epoxy resin',
      '1 set epoxy resin',
      '2 sets epoxy resin',
      '3 sets epoxy resin',
      '500mm timber splice repair',
      '1000mm timber splice repair',
      'Conservation joint repair',
      'Easing and adjusting of sash window',
      'Front face repair to timber cill',
      'New bottom rail to window casement',
      'New glazing panel',
      'New timber cill complete',
      'New timber sash complete',
      'Replacement sash cords',
      'Splice repair to window jamb',
      'Whole tube of epoxy resin'
    ]
  end

  def self.default_price_for_name(tool_name)
    return nil unless tool_name.present?

    prices = {
      'No Works Required' => 0,
      '½ set epoxy resin' => 60,
      '1 set epoxy resin' => 100,
      '2 sets epoxy resin' => 200,
      '3 sets epoxy resin' => 300,
      '500mm timber splice repair' => 70,
      '1000mm timber splice repair' => 120,
      'Conservation joint repair' => 25,
      'Easing and adjusting of sash window' => 288,
      'Front face repair to timber cill' => 221,
      'New bottom rail to window casement' => 221,
      'New glazing panel' => 288,
      'New timber cill complete' => 221,
      'New timber sash complete' => 1210,
      'Replacement sash cords' => 144,
      'Splice repair to window jamb' => 145,
      'Whole tube of epoxy resin' => 100
    }

    prices[tool_name]
  end

  private

  def set_default_price
    default_price = self.class.default_price_for_name(name)
    self.price = default_price if default_price.present? && price.blank?
  end
end
