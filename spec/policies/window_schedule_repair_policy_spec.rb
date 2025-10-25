# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WindowScheduleRepairPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:employee_user) { create(:user, :employee) }
  let(:other_user) { create(:user) }

  let(:window_schedule_repair) { create(:window_schedule_repair, user: user) }

  let(:policy) { described_class.new(user, window_schedule_repair) }
  let(:admin_policy) { described_class.new(admin_user, window_schedule_repair) }
  let(:employee_policy) { described_class.new(employee_user, window_schedule_repair) }
  let(:other_policy) { described_class.new(other_user, window_schedule_repair) }

  describe 'permissions' do
    describe '#index?' do
      it 'allows any authenticated user to view index' do
        expect(policy.index?).to be true
      end
    end

    describe '#show?' do
      it 'allows user to view their own WRS' do
        expect(policy.show?).to be true
      end

      it 'allows admin to view any WRS' do
        expect(admin_policy.show?).to be true
      end

      it 'allows employee to view any WRS' do
        expect(employee_policy.show?).to be true
      end

      it 'does not allow other users to view WRS' do
        expect(other_policy.show?).to be false
      end
    end

    describe '#create?' do
      it 'allows any authenticated user to create WRS' do
        expect(policy.create?).to be true
      end
    end

    describe '#update?' do
      it 'allows user to update their own WRS' do
        expect(policy.update?).to be true
      end

      it 'allows admin to update any WRS' do
        expect(admin_policy.update?).to be true
      end

      it 'allows employee to update any WRS' do
        expect(employee_policy.update?).to be true
      end

      it 'does not allow other users to update WRS' do
        expect(other_policy.update?).to be false
      end
    end

    describe '#destroy?' do
      it 'allows user to destroy their own WRS' do
        expect(policy.destroy?).to be true
      end

      it 'allows admin to destroy any WRS' do
        expect(admin_policy.destroy?).to be true
      end

      it 'does not allow employee to destroy WRS' do
        expect(employee_policy.destroy?).to be false
      end

      it 'does not allow other users to destroy WRS' do
        expect(other_policy.destroy?).to be false
      end
    end

    describe '#restore?' do
      it 'allows user to restore their own WRS' do
        expect(policy.restore?).to be true
      end

      it 'allows admin to restore any WRS' do
        expect(admin_policy.restore?).to be true
      end

      it 'does not allow employee to restore WRS' do
        expect(employee_policy.restore?).to be false
      end

      it 'does not allow other users to restore WRS' do
        expect(other_policy.restore?).to be false
      end
    end

    describe 'Webflow permissions' do
      describe '#send_to_webflow?' do
        it 'allows users with webflow access' do
          expect(admin_policy.send_to_webflow?).to be true
          expect(employee_policy.send_to_webflow?).to be true
        end

        it 'does not allow users without webflow access' do
          expect(policy.send_to_webflow?).to be false
        end
      end

      describe '#publish_to_webflow?' do
        it 'allows users with webflow access' do
          expect(admin_policy.publish_to_webflow?).to be true
          expect(employee_policy.publish_to_webflow?).to be true
        end

        it 'does not allow users without webflow access' do
          expect(policy.publish_to_webflow?).to be false
        end
      end

      describe '#unpublish_from_webflow?' do
        it 'allows users with webflow access' do
          expect(admin_policy.unpublish_from_webflow?).to be true
          expect(employee_policy.unpublish_from_webflow?).to be true
        end

        it 'does not allow users without webflow access' do
          expect(policy.unpublish_from_webflow?).to be false
        end
      end
    end
  end

  describe 'scope' do
    let(:scope) { WindowScheduleRepair.all }
    let(:policy_scope) { described_class::Scope.new(user, scope) }
    let(:admin_policy_scope) { described_class::Scope.new(admin_user, scope) }
    let(:employee_policy_scope) { described_class::Scope.new(employee_user, scope) }

    it 'returns user\'s WRS for regular user' do
      # Create additional WRS for other users
      create(:window_schedule_repair, user: other_user)

      resolved_scope = policy_scope.resolve
      expect(resolved_scope).to include(window_schedule_repair)
      expect(resolved_scope.count).to eq(1)
    end

    it 'returns all WRS for admin' do
      resolved_scope = admin_policy_scope.resolve
      expect(resolved_scope).to include(window_schedule_repair)
    end

    it 'returns employee\'s own WRS' do
      # Create a WRS for the employee
      employee_wrs = create(:window_schedule_repair, user: employee_user)

      resolved_scope = employee_policy_scope.resolve
      expect(resolved_scope).to include(employee_wrs)
      expect(resolved_scope).not_to include(window_schedule_repair) # Should not include other user's WRS
    end
  end
end
