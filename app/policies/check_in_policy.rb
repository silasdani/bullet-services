# frozen_string_literal: true

class CheckInPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && (user.admin? || record.user == user)
  end

  def check_in?
    user.present? && user.contractor?
  end

  def check_out?
    user.present? && user.contractor?
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
