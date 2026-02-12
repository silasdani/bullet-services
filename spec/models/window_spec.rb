# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Window, type: :model do
  let(:user) { create(:user) }
  let(:work_order) do
    create(:work_order, user: user)
  end
  let(:window) { build(:window, work_order: work_order) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(window).to be_valid
    end

    it 'requires location to be present' do
      window.location = nil
      expect(window).not_to be_valid
      expect(window.errors[:location]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to work_order' do
      expect(window).to respond_to(:work_order)
      expect(window.work_order).to eq(work_order)
    end

    it 'is destroyed when work_order is destroyed' do
      window.save!
      expect do
        work_order.destroy
      end.to change(Window, :count).by(-1)
    end
  end

  describe 'factory' do
    it 'creates a valid window' do
      expect(window).to be_valid
    end
  end
end
