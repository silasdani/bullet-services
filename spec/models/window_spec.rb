# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Window, type: :model do
  let(:user) { create(:user) }
  let(:window_schedule_repair) do
    create(:window_schedule_repair, user: user)
  end
  let(:window) { build(:window, window_schedule_repair: window_schedule_repair) }

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
    it 'belongs to window_schedule_repair' do
      expect(window).to respond_to(:window_schedule_repair)
      expect(window.window_schedule_repair).to eq(window_schedule_repair)
    end

    it 'is destroyed when window_schedule_repair is destroyed' do
      window.save!
      expect do
        window_schedule_repair.destroy
      end.to change(Window, :count).by(-1)
    end
  end

  describe 'factory' do
    it 'creates a valid window' do
      expect(window).to be_valid
    end
  end
end
