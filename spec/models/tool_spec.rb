# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tool, type: :model do
  let(:user) { create(:user) }
  let(:work_order) { create(:work_order, user: user) }
  let(:window) { create(:window, work_order: work_order) }
  let(:tool) { build(:tool, window: window) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(tool).to be_valid
    end

    it 'requires name to be present' do
      tool.name = nil
      expect(tool).not_to be_valid
      expect(tool.errors[:name]).to include("can't be blank")
    end

    it 'requires price to be present' do
      tool.price = nil
      expect(tool).not_to be_valid
      expect(tool.errors[:price]).to include("can't be blank")
    end
  end

  describe 'associations' do
    it 'belongs to window' do
      expect(tool).to respond_to(:window)
      expect(tool.window).to eq(window)
    end
  end

  describe 'factory' do
    it 'creates a valid tool' do
      expect(tool).to be_valid
    end
  end
end
