# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assignment, type: :model do
  describe 'associations' do
    it 'belongs to user' do
      expect(Assignment.reflect_on_association(:user)).to be_present
    end

    it 'belongs to building' do
      expect(Assignment.reflect_on_association(:building)).to be_present
    end

    it 'optionally belongs to assigned_by_user' do
      assoc = Assignment.reflect_on_association(:assigned_by_user)
      expect(assoc).to be_present
      expect(assoc.options[:optional]).to be true
    end
  end

  describe 'validations' do
    it 'requires user_id' do
      a = Assignment.new(building: create(:building))
      expect(a).not_to be_valid
      expect(a.errors[:user_id]).to include("can't be blank")
    end

    it 'requires building_id' do
      a = Assignment.new(user: create(:user))
      expect(a).not_to be_valid
      expect(a.errors[:building_id]).to include("can't be blank")
    end

    it 'enforces unique user+building' do
      user = create(:user)
      building = create(:building)
      Assignment.create!(user: user, building: building)
      dup = Assignment.new(user: user, building: building)
      expect(dup).not_to be_valid
    end
  end

  describe 'enum' do
    it 'has expected project roles' do
      expect(Assignment.roles.keys).to match_array(
        %w[contractor surveyor general_contractor supervisor contract_manager]
      )
    end

    it 'does NOT include admin or client' do
      expect(Assignment.roles.keys).not_to include('admin')
      expect(Assignment.roles.keys).not_to include('client')
    end
  end

  describe 'default role assignment' do
    let(:building) { create(:building) }

    context 'when user is a contractor' do
      let(:user) { create(:user, role: :contractor) }

      it 'defaults assignment role to contractor' do
        a = Assignment.create!(user: user, building: building)
        expect(a.role).to eq('contractor')
      end
    end

    context 'when user is a supervisor' do
      let(:user) { create(:user, role: :supervisor) }

      it 'defaults assignment role to supervisor' do
        a = Assignment.create!(user: user, building: building)
        expect(a.role).to eq('supervisor')
      end
    end

    context 'when user is a contract_manager' do
      let(:user) { create(:user, role: :contract_manager) }

      it 'defaults assignment role to contract_manager' do
        a = Assignment.create!(user: user, building: building)
        expect(a.role).to eq('contract_manager')
      end
    end

    context 'when user is an admin (forbidden project role)' do
      let(:user) { create(:user, :admin) }

      it 'defaults assignment role to contract_manager' do
        a = Assignment.create!(user: user, building: building)
        expect(a.role).to eq('contract_manager')
      end
    end

    context 'when user is a general_contractor' do
      let(:user) { create(:user, role: :general_contractor) }

      it 'defaults assignment role to general_contractor' do
        a = Assignment.create!(user: user, building: building)
        expect(a.role).to eq('general_contractor')
      end
    end

    context 'when user is a surveyor' do
      let(:user) { create(:user, role: :surveyor) }

      it 'defaults assignment role to surveyor' do
        a = Assignment.create!(user: user, building: building)
        expect(a.role).to eq('surveyor')
      end
    end

    context 'when role is explicitly set' do
      let(:user) { create(:user, role: :contractor) }

      it 'uses the explicitly set role' do
        a = Assignment.create!(user: user, building: building, role: :supervisor)
        expect(a.role).to eq('supervisor')
      end
    end
  end
end
