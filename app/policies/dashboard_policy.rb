class DashboardPolicy < ApplicationPolicy
  def dashboard?
    user.admin?
  end

  def index?
    user.admin?
  end

  def show?
    user.admin?
  end

  def new?
    user.admin?
  end

  def create?
    user.admin?
  end

  def edit?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
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
