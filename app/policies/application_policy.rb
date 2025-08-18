# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # RailsAdmin specific methods
  def dashboard?
    user.present? && user.is_admin?
  end

  def index?
    user.present? && user.is_admin?
  end

  def show?
    user.present? && user.is_admin?
  end

  def new?
    user.present? && user.is_admin?
  end

  def create?
    user.present? && user.is_admin?
  end

  def edit?
    user.present? && user.is_admin?
  end

  def update?
    user.present? && user.is_admin?
  end

  def destroy?
    user.present? && user.is_admin?
  end

  def export?
    user.present? && user.is_admin?
  end

  def history?
    user.present? && user.is_admin?
  end

  def show_in_app?
    user.present? && user.is_admin?
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end
end
