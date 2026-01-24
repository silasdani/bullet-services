# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it 'has many window_schedule_repairs' do
      expect(User.reflect_on_association(:window_schedule_repairs)).to be_present
    end

    it 'has many windows through window_schedule_repairs' do
      expect(User.reflect_on_association(:windows)).to be_present
    end
  end

  describe 'validations' do
    it 'validates presence of email' do
      user = User.new(password: 'password123', role: :client)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'validates presence of password' do
      user = User.new(email: 'test@example.com', role: :client)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end
  end

  describe 'enums' do
    it 'has role enum with correct values' do
      expect(User.roles).to eq({
                                 'client' => 0,
                                 'surveyor' => 1,
                                 'admin' => 2,
                                 'super_admin' => 3
                               })
    end
  end

  describe 'role helper methods' do
    let(:user) { create(:user) }

    context 'when user is admin' do
      let(:admin_user) { create(:user, :admin) }

      it 'returns true for is_admin?' do
        expect(admin_user.is_admin?).to be true
      end

      it 'returns true for webflow_access' do
        expect(admin_user.webflow_access).to be true
      end
    end

    context 'when user is surveyor' do
      let(:surveyor_user) { create(:user, :surveyor) }

      it 'returns true for is_employee? (deprecated alias)' do
        expect(surveyor_user.is_employee?).to be true
      end

      it 'returns true for surveyor?' do
        expect(surveyor_user.surveyor?).to be true
      end

      it 'returns true for webflow_access' do
        expect(surveyor_user.webflow_access).to be true
      end
    end

    context 'when user is client' do
      it 'returns false for is_admin?' do
        expect(user.is_admin?).to be false
      end

      it 'returns false for is_employee?' do
        expect(user.is_employee?).to be false
      end

      it 'returns false for webflow_access' do
        expect(user.webflow_access).to be false
      end
    end
  end

  describe 'soft delete functionality' do
    let(:user) { create(:user) }

    it 'can be soft deleted' do
      expect { user.soft_delete! }.to change { user.deleted_at }.from(nil)
    end

    it 'can be restored' do
      user.soft_delete!
      expect { user.restore! }.to change { user.deleted_at }.to(nil)
    end

    it 'knows if it is deleted' do
      expect(user.deleted?).to be false
      user.soft_delete!
      expect(user.deleted?).to be true
    end

    it 'knows if it is active' do
      expect(user.active?).to be true
      user.soft_delete!
      expect(user.active?).to be false
    end
  end

  describe 'default role assignment' do
    it 'assigns client role by default' do
      user = User.new(email: 'test@example.com', password: 'password123')
      user.save!
      expect(user.role).to eq('client')
    end
  end

  describe 'confirmation' do
    it 'sets confirmed_at after creation' do
      user = create(:user)
      expect(user.confirmed_at).to be_present
    end
  end
end
