class DashboardPolicy < ApplicationPolicy
  def dashboard?
    user.is_admin?
  end

  def index?
    user.is_admin?
  end

  def show?
    user.is_admin?
  end

  def new?
    user.is_admin?
  end

  def create?
    user.is_admin?
  end

  def edit?
    user.is_admin?
  end

  def update?
    user.is_admin?
  end

  def destroy?
    user.is_admin?
  end

  def export?
    user.is_admin?
  end

  def history?
    user.is_admin?
  end

  def show_in_app?
    user.is_admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
