class AdminPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def show?
    user.admin? || record == user
  end

  def create?
    user.admin?
  end

  def update?
    user.admin? || record == user
  end

  def destroy?
    user.admin?
  end

  def me?
    user.present?
  end

  # RailsAdmin specific methods
  def dashboard?
    user.admin?
  end

  def export?
    user.admin?
  end

  def history?
    user.admin?
  end

  def show_in_app?
    user.admin?
  end
end
