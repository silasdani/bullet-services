# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:contractor_user) { create(:user, :contractor) }
  let(:other_user) { create(:user) }

  let(:work_order) { create(:work_order, user: user) }

  let(:policy) { described_class.new(user, work_order) }
  let(:admin_policy) { described_class.new(admin_user, work_order) }
  let(:contractor_policy) { described_class.new(contractor_user, work_order) }
  let(:other_policy) { described_class.new(other_user, work_order) }

  describe 'permissions' do
    describe '#index?' do
      it 'allows any authenticated user to view index' do
        expect(policy.index?).to be true
      end
    end

    describe '#show?' do
      it 'allows user to view their own work order' do
        expect(policy.show?).to be true
      end

      it 'allows admin to view any work order' do
        expect(admin_policy.show?).to be true
      end

      it 'allows contractor to view any work order' do
        expect(contractor_policy.show?).to be true
      end

      it 'does not allow other users to view work order' do
        expect(other_policy.show?).to be false
      end
    end

    describe '#create?' do
      it 'allows any authenticated user to create work order' do
        expect(policy.create?).to be true
      end
    end

    describe '#update?' do
      it 'allows user to update their own work order' do
        expect(policy.update?).to be true
      end

      it 'allows admin to update any work order' do
        expect(admin_policy.update?).to be true
      end

      it 'allows contractor to update any work order' do
        expect(contractor_policy.update?).to be true
      end

      it 'does not allow other users to update work order' do
        expect(other_policy.update?).to be false
      end
    end

    describe '#destroy?' do
      it 'allows user to destroy their own work order' do
        expect(policy.destroy?).to be true
      end

      it 'allows admin to destroy any work order' do
        expect(admin_policy.destroy?).to be true
      end

      it 'does not allow contractor to destroy work order' do
        expect(contractor_policy.destroy?).to be false
      end

      it 'does not allow other users to destroy work order' do
        expect(other_policy.destroy?).to be false
      end
    end

    describe '#restore?' do
      it 'allows user to restore their own work order' do
        expect(policy.restore?).to be true
      end

      it 'allows admin to restore any work order' do
        expect(admin_policy.restore?).to be true
      end

      it 'does not allow contractor to restore work order' do
        expect(contractor_policy.restore?).to be false
      end

      it 'does not allow other users to restore work order' do
        expect(other_policy.restore?).to be false
      end
    end
  end

  describe 'scope' do
    let(:scope) { WorkOrder.all }
    let(:policy_scope) { described_class::Scope.new(user, scope) }
    let(:admin_policy_scope) { described_class::Scope.new(admin_user, scope) }
    let(:contractor_policy_scope) { described_class::Scope.new(contractor_user, scope) }

    it 'returns user\'s work orders for regular user' do
      # Create additional work orders for other users
      create(:work_order, user: other_user)

      resolved_scope = policy_scope.resolve
      expect(resolved_scope).to include(work_order)
      expect(resolved_scope.count).to eq(1)
    end

    it 'returns all work orders for admin' do
      resolved_scope = admin_policy_scope.resolve
      expect(resolved_scope).to include(work_order)
    end

    it 'returns contractor\'s own work orders' do
      # Create a work order for the contractor
      contractor_work_order = create(:work_order, user: contractor_user)

      resolved_scope = contractor_policy_scope.resolve
      expect(resolved_scope).to include(contractor_work_order)
      expect(resolved_scope).not_to include(work_order) # Should not include other user's work orders
    end
  end
end
