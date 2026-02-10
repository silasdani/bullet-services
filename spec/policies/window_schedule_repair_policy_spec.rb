# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WindowScheduleRepairPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:contractor_user) { create(:user, :contractor) }
  let(:other_user) { create(:user) }

  let(:window_schedule_repair) { create(:window_schedule_repair, user: user) }

  let(:policy) { described_class.new(user, window_schedule_repair) }
  let(:admin_policy) { described_class.new(admin_user, window_schedule_repair) }
  let(:contractor_policy) { described_class.new(contractor_user, window_schedule_repair) }
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

      it 'allows contractor to view any WRS' do
        expect(contractor_policy.show?).to be true
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

      it 'allows contractor to update any WRS' do
        expect(contractor_policy.update?).to be true
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

      it 'does not allow contractor to destroy WRS' do
        expect(contractor_policy.destroy?).to be false
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

      it 'does not allow contractor to restore WRS' do
        expect(contractor_policy.restore?).to be false
      end

      it 'does not allow other users to restore WRS' do
        expect(other_policy.restore?).to be false
      end
    end
  end

  describe 'scope' do
    let(:scope) { WindowScheduleRepair.all }
    let(:policy_scope) { described_class::Scope.new(user, scope) }
    let(:admin_policy_scope) { described_class::Scope.new(admin_user, scope) }
    let(:contractor_policy_scope) { described_class::Scope.new(contractor_user, scope) }

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

    it 'returns contractor\'s own WRS' do
      # Create a WRS for the contractor
      contractor_wrs = create(:window_schedule_repair, user: contractor_user)

      resolved_scope = contractor_policy_scope.resolve
      expect(resolved_scope).to include(contractor_wrs)
      expect(resolved_scope).not_to include(window_schedule_repair) # Should not include other user's WRS
    end
  end
end
