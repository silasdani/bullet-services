# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && record.user == user
  end

  def mark_read?
    user.present? && record.user == user
  end

  def mark_unread?
    user.present? && record.user == user
  end

  def mark_all_read?
    user.present?
  end

  class Scope < Scope
    def resolve
      scope.where(user: user)
    end
  end
end
