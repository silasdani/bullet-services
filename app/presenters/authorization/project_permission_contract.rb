# frozen_string_literal: true

module Authorization
  # Converts project-scoped Pundit/resolver checks into a CASL-compatible
  # JSON array.  Designed as the single export point so the mobile app
  # never re-implements permission logic.
  #
  # Usage:
  #   Authorization::ProjectPermissionContract.new(user: current_user, building: @building).as_json
  #   # => [{ action: "read", subject: "Project" }, { action: "create", subject: "WorkOrder" }, ...]
  #
  class ProjectPermissionContract
    Rule = Struct.new(:action, :subject, keyword_init: true)

    def initialize(user:, building:)
      @user = user
      @building = building
      @resolver = ProjectRoleResolver.new(user: user, building: building)
      @building_policy = BuildingPolicy.new(user, building)
    end

    def as_json(_options = nil)
      rules.compact.map { |rule| { action: rule.action, subject: rule.subject } }
    end

    private

    attr_reader :user, :building, :resolver, :building_policy

    def rules
      [
        (Rule.new(action: 'read',   subject: 'Project')   if building_policy.show?),
        (Rule.new(action: 'update', subject: 'Project')   if resolver.can_edit_building?),
        (Rule.new(action: 'read',   subject: 'WorkOrder') if building_policy.show?),
        (Rule.new(action: 'create', subject: 'WorkOrder') if resolver.can_create_work_order?),
        (Rule.new(action: 'update', subject: 'WorkOrder') if resolver.manager?),
        (Rule.new(action: 'publish', subject: 'WorkOrder') if resolver.can_publish_work_order?),
        (Rule.new(action: 'delete', subject: 'WorkOrder') if resolver.can_delete_work_order?(sentinel_work_order)),
        (Rule.new(action: 'read',   subject: 'Price')     if resolver.can_view_prices?),
        (Rule.new(action: 'update', subject: 'ScheduleOfCondition') if resolver.can_edit_schedule_of_condition?),
        (Rule.new(action: 'checkin', subject: 'WorkOrder') if resolver.can_check_in?),
        (Rule.new(action: 'assign', subject: 'User') if resolver.can_assign_users?)
      ]
    end

    # Sentinel used for ownership-dependent checks where we test the
    # user's own ownership (worst-case: user owns the record).
    def sentinel_work_order
      Struct.new(:user_id).new(user.id)
    end
  end
end
