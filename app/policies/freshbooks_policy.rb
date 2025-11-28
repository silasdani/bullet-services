# frozen_string_literal: true

class FreshbooksPolicy < ApplicationPolicy
  def manage?
    user.is_admin? || user.is_super_admin?
  end
end
