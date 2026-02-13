# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrders::CreationService do
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
      it 'creates a work order' do
        expect do
          described_class.new(user: user, params: valid_params).call
        end.to change(WorkOrder, :count).by(1)
      end

      it 'creates associated windows' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:work_order].windows.count).to eq(2)
      end

      it 'creates associated tools' do
        result = described_class.new(user: user, params: valid_params).call
        total_tools = result[:work_order].windows.sum { |w| w.tools.count }
        expect(total_tools).to eq(3)
      end

      it 'calculates totals correctly' do
        result = described_class.new(user: user, params: valid_params).call
        work_order = result[:work_order]
        expect(work_order.total_vat_excluded_price).to eq(225.0)
        expect(work_order.total_vat_included_price).to eq(270.0) # 20% VAT
        expect(work_order.grand_total).to eq(270.0)
      end

      it 'returns success result' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:success]).to be true
        expect(result[:work_order]).to be_a(WorkOrder)
      end

      it 'generates a slug automatically' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:work_order].slug).to be_present
        expect(result[:work_order].slug).to include('123-test-st')
        expect(result[:work_order].slug).to include('apt-1')
      end

      it 'sets status to pending' do
        result = described_class.new(user: user, params: valid_params).call
        expect(result[:work_order].status).to eq('pending')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { valid_params.merge(name: '') }

      it 'does not create a work order' do
        expect do
          described_class.new(user: user, params: invalid_params).call
        end.not_to change(WorkOrder, :count)
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

      it 'does not create a work order' do
        expect do
          described_class.new(user: user, params: incomplete_params).call
        end.not_to change(WorkOrder, :count)
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
      allow_any_instance_of(WorkOrder).to receive(:save!).and_raise(
        ActiveRecord::RecordInvalid.new(WorkOrder.new)
      )

      expect do
        described_class.new(user: user, params: valid_params).call
      end.not_to change(WorkOrder, :count)
    end
  end
end
