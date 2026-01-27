# frozen_string_literal: true

class WindowScheduleRepairPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false unless user.present?
    # Contractors cannot see draft WRSes
    return false if user.contractor? && record.draft?
    true
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (user.is_admin? || user.is_employee? || record.user == user)
  end

  def destroy?
    user.present? && (user.is_admin? || record.user == user)
  end

  def restore?
    user.present? && (user.is_admin? || record.user == user)
  end

  def send_to_webflow?
    user.present? && user.webflow_access
  end

  def publish_to_webflow?
    user.present? && user.webflow_access
  end

  def unpublish_from_webflow?
    user.present? && user.webflow_access
  end

  class Scope < Scope
    def resolve
      # Contractors cannot see draft WRSes
      if user.contractor?
        scope.where(is_draft: false)
      else
        # Admins, clients, and surveyors can see all WRS
        scope.all
      end
    end
  end
end
