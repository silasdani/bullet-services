# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WindowPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:employee_user) { create(:user, :employee) }
  let(:other_user) { create(:user) }

  let(:window_schedule_repair) { create(:window_schedule_repair, user: user) }
  let(:window) { create(:window, window_schedule_repair: window_schedule_repair) }

  let(:policy) { described_class.new(user, window) }
  let(:admin_policy) { described_class.new(admin_user, window) }
  let(:employee_policy) { described_class.new(employee_user, window) }
  let(:other_policy) { described_class.new(other_user, window) }

  describe 'permissions' do
    describe '#show?' do
      it 'allows user to view their own windows' do
        expect(policy.show?).to be true
      end

      it 'allows admin to view any window' do
        expect(admin_policy.show?).to be true
      end

      it 'allows employee to view any window' do
        expect(employee_policy.show?).to be true
      end

      it 'does not allow other users to view windows' do
        expect(other_policy.show?).to be false
      end
    end

    describe '#create?' do
      it 'allows user to create windows' do
        expect(policy.create?).to be true
      end
    end

    describe '#update?' do
      it 'allows user to update their own windows' do
        expect(policy.update?).to be true
      end

      it 'allows admin to update any window' do
        expect(admin_policy.update?).to be true
      end

      it 'allows employee to update any window' do
        expect(employee_policy.update?).to be true
      end

      it 'does not allow other users to update windows' do
        expect(other_policy.update?).to be false
      end
    end

    describe '#destroy?' do
      it 'allows user to destroy their own windows' do
        expect(policy.destroy?).to be true
      end

      it 'allows admin to destroy any window' do
        expect(admin_policy.destroy?).to be true
      end

      it 'does not allow employee to destroy windows' do
        expect(employee_policy.destroy?).to be false
      end

      it 'does not allow other users to destroy windows' do
        expect(other_policy.destroy?).to be false
      end
    end
  end

  describe 'scope' do
    let(:scope) { Window.all }
    let(:policy_scope) { described_class::Scope.new(user, scope) }
    let(:admin_policy_scope) { described_class::Scope.new(admin_user, scope) }
    let(:employee_policy_scope) { described_class::Scope.new(employee_user, scope) }

    it 'returns user\'s windows for regular user' do
      # Create additional windows for other users
      other_wrs = create(:window_schedule_repair, user: other_user)
      create(:window, window_schedule_repair: other_wrs)

      resolved_scope = policy_scope.resolve
      expect(resolved_scope).to include(window)
      expect(resolved_scope.count).to eq(1)
    end

    it 'returns all windows for admin' do
      resolved_scope = admin_policy_scope.resolve
      expect(resolved_scope).to include(window)
    end

    it 'returns employee\'s own windows' do
      # Create a window for the employee
      employee_wrs = create(:window_schedule_repair, user: employee_user)
      employee_window = create(:window, window_schedule_repair: employee_wrs)

      resolved_scope = employee_policy_scope.resolve
      expect(resolved_scope).to include(employee_window)
      expect(resolved_scope).not_to include(window) # Should not include other user's windows
    end
  end
end
