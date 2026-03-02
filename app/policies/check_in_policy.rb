# frozen_string_literal: true

class CheckInPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.admin? || record.user == user)
  end

  def active?
    user.present?
  end

  def check_in?
    user.present? && (user.contractor? || user.general_contractor? || user.admin?)
  end

  def check_out?
    user.present? && (user.contractor? || user.general_contractor? || user.admin?)
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end
end
