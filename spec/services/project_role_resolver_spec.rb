# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectRoleResolver do
  let(:building) { create(:building) }

  # ---------------------------------------------------------------------------
  # Default role: user.role matches assignment.role
  # ---------------------------------------------------------------------------
  describe 'default role (global role == project role)' do
    %i[contractor general_contractor supervisor contract_manager surveyor].each do |role|
      context "when global role is #{role}" do
        let(:user) { create(:user, role: role) }
        let!(:assignment) { Assignment.create!(user: user, building: building) }
        let(:resolver) { described_class.new(user: user, building: building) }

        it "resolves effective_role to #{role}" do
          expect(resolver.effective_role).to eq(role.to_s)
        end

        it 'reports assigned?' do
          expect(resolver.assigned?).to be true
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Overridden role: user.role != assignment.role
  # ---------------------------------------------------------------------------
  describe 'overridden role (project role differs from global)' do
    context 'global supervisor, project contractor' do
      let(:user) { create(:user, role: :supervisor) }
      let!(:assignment) { Assignment.create!(user: user, building: building, role: :contractor) }
      let(:resolver) { described_class.new(user: user, building: building) }

      it 'resolves to contractor' do
        expect(resolver.effective_role).to eq('contractor')
      end

      it 'is a field_worker' do
        expect(resolver.field_worker?).to be true
      end

      it 'is NOT a manager' do
        expect(resolver.manager?).to be false
      end

      it 'cannot create work orders' do
        expect(resolver.can_create_work_order?).to be false
      end

      it 'can check in' do
        expect(resolver.can_check_in?).to be true
      end
    end

    context 'global contractor, project supervisor' do
      let(:user) { create(:user, role: :contractor) }
      let!(:assignment) { Assignment.create!(user: user, building: building, role: :supervisor) }
      let(:resolver) { described_class.new(user: user, building: building) }

      it 'resolves to supervisor' do
        expect(resolver.effective_role).to eq('supervisor')
      end

      it 'is a manager' do
        expect(resolver.manager?).to be true
      end

      it 'is NOT a field_worker' do
        expect(resolver.field_worker?).to be false
      end

      it 'can create work orders' do
        expect(resolver.can_create_work_order?).to be true
      end

      it 'can edit building' do
        expect(resolver.can_edit_building?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Admin default: admin user defaults to contract_manager on project
  # ---------------------------------------------------------------------------
  describe 'admin default (contract_manager on project)' do
    let(:user) { create(:user, :admin) }
    let!(:assignment) { Assignment.create!(user: user, building: building) }
    let(:resolver) { described_class.new(user: user, building: building) }

    it 'defaults assignment role to contract_manager' do
      expect(assignment.role).to eq('contract_manager')
    end

    it 'resolves effective_role to contract_manager' do
      expect(resolver.effective_role).to eq('contract_manager')
    end

    it 'can create work orders (admin bypass)' do
      expect(resolver.can_create_work_order?).to be true
    end

    it 'can view prices (admin bypass)' do
      expect(resolver.can_view_prices?).to be true
    end

    it 'can assign users (admin bypass)' do
      expect(resolver.can_assign_users?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # No assignment: user has no project access
  # ---------------------------------------------------------------------------
  describe 'no assignment' do
    let(:user) { create(:user, role: :contractor) }
    let(:resolver) { described_class.new(user: user, building: building) }

    it 'returns nil effective_role' do
      expect(resolver.effective_role).to be_nil
    end

    it 'is not assigned' do
      expect(resolver.assigned?).to be false
    end

    it 'is not a field_worker' do
      expect(resolver.field_worker?).to be false
    end

    it 'cannot create work orders' do
      expect(resolver.can_create_work_order?).to be false
    end

    it 'cannot check in' do
      expect(resolver.can_check_in?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Permission matrix by project role
  # ---------------------------------------------------------------------------
  describe 'permission matrix' do
    let(:user) { create(:user, role: :contractor) }
    let(:wo_owner) { user }
    let(:other_user) { create(:user, role: :supervisor) }
    let(:work_order) { create(:work_order, user: wo_owner, building: building) }

    shared_examples 'field worker permissions' do
      it { expect(resolver.field_worker?).to be true }
      it { expect(resolver.manager?).to be false }
      it { expect(resolver.can_create_work_order?).to be false }
      it { expect(resolver.can_check_in?).to be true }
      it { expect(resolver.can_edit_building?).to be false }
      it { expect(resolver.can_view_prices?).to be false }
      it { expect(resolver.can_assign_users?).to be false }
    end

    shared_examples 'management permissions' do
      it { expect(resolver.field_worker?).to be false }
      it { expect(resolver.manager?).to be true }
      it { expect(resolver.can_edit_building?).to be true }
    end

    context 'contractor on project' do
      let!(:assignment) { Assignment.create!(user: user, building: building, role: :contractor) }
      let(:resolver) { described_class.new(user: user, building: building) }

      include_examples 'field worker permissions'
    end

    context 'general_contractor on project' do
      let!(:assignment) { Assignment.create!(user: user, building: building, role: :general_contractor) }
      let(:resolver) { described_class.new(user: user, building: building) }

      include_examples 'field worker permissions'
    end

    context 'supervisor on project' do
      let!(:assignment) { Assignment.create!(user: user, building: building, role: :supervisor) }
      let(:resolver) { described_class.new(user: user, building: building) }

      include_examples 'management permissions'

      it 'can create work orders' do
        expect(resolver.can_create_work_order?).to be true
      end

      it 'can edit own work orders' do
        expect(resolver.can_edit_work_order?(work_order)).to be true
      end

      it 'cannot edit others work orders' do
        other_wo = create(:work_order, user: other_user, building: building)
        expect(resolver.can_edit_work_order?(other_wo)).to be false
      end

      it 'can edit schedule of condition' do
        expect(resolver.can_edit_schedule_of_condition?).to be true
      end

      it 'cannot view prices' do
        expect(resolver.can_view_prices?).to be false
      end
    end

    context 'contract_manager on project' do
      let!(:assignment) { Assignment.create!(user: user, building: building, role: :contract_manager) }
      let(:resolver) { described_class.new(user: user, building: building) }

      include_examples 'management permissions'

      it 'can create work orders' do
        expect(resolver.can_create_work_order?).to be true
      end

      it 'can edit any work order' do
        other_wo = create(:work_order, user: other_user, building: building)
        expect(resolver.can_edit_work_order?(other_wo)).to be true
      end

      it 'can publish work orders' do
        expect(resolver.can_publish_work_order?).to be true
      end

      it 'can view prices' do
        expect(resolver.can_view_prices?).to be true
      end

      it 'can assign users' do
        expect(resolver.can_assign_users?).to be true
      end
    end

    context 'surveyor on project' do
      let!(:assignment) { Assignment.create!(user: user, building: building, role: :surveyor) }
      let(:resolver) { described_class.new(user: user, building: building) }

      include_examples 'management permissions'

      it 'cannot create work orders' do
        expect(resolver.can_create_work_order?).to be false
      end

      it 'cannot view prices' do
        expect(resolver.can_view_prices?).to be false
      end
    end
  end
end
