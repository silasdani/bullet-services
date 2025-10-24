# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:policy) { described_class.new(user, user) }
  let(:other_policy) { described_class.new(user, other_user) }
  let(:admin_policy) { described_class.new(admin_user, user) }

  describe 'permissions' do
    describe '#show?' do
      it 'allows user to view their own profile' do
        expect(policy.show?).to be true
      end

      it 'allows admin to view any user' do
        expect(admin_policy.show?).to be true
      end

      it 'does not allow user to view other users' do
        expect(other_policy.show?).to be false
      end
    end

    describe '#create?' do
      it 'allows admin to create users' do
        expect(admin_policy.create?).to be true
      end

      it 'does not allow regular users to create users' do
        expect(policy.create?).to be false
      end
    end

    describe '#update?' do
      it 'allows user to update their own profile' do
        expect(policy.update?).to be true
      end

      it 'allows admin to update any user' do
        expect(admin_policy.update?).to be true
      end

      it 'does not allow user to update other users' do
        expect(other_policy.update?).to be false
      end
    end

    describe '#destroy?' do
      it 'allows user to delete their own account' do
        expect(policy.destroy?).to be true
      end

      it 'allows admin to delete any user' do
        expect(admin_policy.destroy?).to be true
      end

      it 'does not allow user to delete other users' do
        expect(other_policy.destroy?).to be false
      end
    end
  end

  describe 'scope' do
    let(:scope) { User.all }
    let(:policy_scope) { described_class::Scope.new(user, scope) }
    let(:admin_policy_scope) { described_class::Scope.new(admin_user, scope) }

    it 'returns all users for admin' do
      expect(admin_policy_scope.resolve).to eq(scope)
    end

    it 'returns only user\'s own record for regular user' do
      resolved_scope = policy_scope.resolve
      expect(resolved_scope).to include(user)
      expect(resolved_scope.count).to eq(1)
    end
  end
end
