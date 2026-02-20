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
      '½ set epoxy resin' => 90,
      '1 set epoxy resin' => 150,
      '2 sets epoxy resin' => 300,
      '3 sets epoxy resin' => 450,
      '500mm timber splice repair' => 90,
      '1000mm timber splice repair' => 150,
      'Conservation joint repair' => 10,
      'Easing and adjusting of sash window' => 100,
      'Front face repair to timber cill' => 225,
      'New bottom rail to window casement' => 130,
      'New glazing panel' => 275,
      'New timber cill complete' => 285,
      'New timber sash complete' => 375,
      'Replacement sash cords' => 100,
      'Splice repair to window jamb' => 100,
      'Whole tube of epoxy resin' => 150
    }

    prices[tool_name]
  end

  private

  def set_default_price
    default_price = self.class.default_price_for_name(name)
    self.price = default_price if default_price.present? && price.blank?
  end
end
