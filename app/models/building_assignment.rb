# frozen_string_literal: true

class BuildingAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :building
  belongs_to :assigned_by_user, class_name: 'User', optional: true

  validates :user_id, presence: true
  validates :building_id, presence: true
  validates :building_id, uniqueness: { scope: :user_id }
end
