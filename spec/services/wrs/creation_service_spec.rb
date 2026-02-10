# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Wrs::CreationService do
  let(:user) { create(:user) }
  let(:building) { create(:building, street: '123 Test St', city: 'London', zipcode: 'W1', country: 'UK') }
  let(:valid_params) do
    {
      name: 'Test WRS',
      building_id: building.id,
      flat_number: 'Apt 1',
      windows_attributes: {
        '0' => {
          location: 'Kitchen',
          tools_attributes: {
            '0' => { name: 'Glass Panel', price: 100 },
            '1' => { name: 'Installation', price: 50 }
          }
        },
        '1' => {
          location: 'Living Room',
          tools_attributes: {
            '0' => { name: 'Frame Repair', price: 75 }
          }
        }
      }
    }
  end

  describe '#call' do
    context 'with valid parameters' do
      it 'creates a window schedule repair' do
        expect do
          described_class.new(user: user, params: valid_params).call
        end.to change(WindowScheduleRepair, :count).by(1)
      end

      it 'creates associated windows' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:wrs].windows.count).to eq(2)
      end

      it 'creates associated tools' do
        result = described_class.new(user: user, params: valid_params).call
        total_tools = result[:wrs].windows.sum { |w| w.tools.count }
        expect(total_tools).to eq(3)
      end

      it 'calculates totals correctly' do
        result = described_class.new(user: user, params: valid_params).call
        wrs = result[:wrs]
        expect(wrs.total_vat_excluded_price).to eq(225.0)
        expect(wrs.total_vat_included_price).to eq(270.0) # 20% VAT
        expect(wrs.grand_total).to eq(270.0)
      end

      it 'returns success result' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:success]).to be true
        expect(result[:wrs]).to be_a(WindowScheduleRepair)
      end

      it 'generates a slug automatically' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:wrs].slug).to be_present
        expect(result[:wrs].slug).to include('123-test-st')
        expect(result[:wrs].slug).to include('apt-1')
      end

      it 'sets status to pending' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:wrs].status).to eq('pending')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { valid_params.merge(name: '') }

      it 'does not create a window schedule repair' do
        expect do
          described_class.new(user: user, params: invalid_params).call
        end.not_to change(WindowScheduleRepair, :count)
      end

      it 'returns failure result' do
        result = described_class.new(user: user, params: invalid_params).call
        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end

      it 'includes validation errors' do
        service = described_class.new(user: user, params: invalid_params)
        result = service.call
        expect(result[:errors].join(' ')).to include("Name can't be blank")
      end
    end

    context 'with missing required fields' do
      let(:incomplete_params) { { name: 'Test WRS' } }

      it 'does not create a window schedule repair' do
        expect do
          described_class.new(user: user, params: incomplete_params).call
        end.not_to change(WindowScheduleRepair, :count)
      end

      it 'returns failure result' do
        result = described_class.new(user: user, params: incomplete_params).call
        expect(result[:success]).to be false
      end
    end

    context 'when user is nil' do
      it 'returns failure result' do
        result = described_class.new(user: nil, params: valid_params).call

        expect(result[:success]).to be false
        expect(result[:errors]).to be_present
      end
    end
  end

  describe 'transaction handling' do
    it 'rolls back all changes if any part fails' do
      # Mock a failure in window creation
      allow_any_instance_of(WindowScheduleRepair).to receive(:save!).and_raise(
        ActiveRecord::RecordInvalid.new(WindowScheduleRepair.new)
      )

      expect do
        described_class.new(user: user, params: valid_params).call
      end.not_to change(WindowScheduleRepair, :count)
    end
  end
end
