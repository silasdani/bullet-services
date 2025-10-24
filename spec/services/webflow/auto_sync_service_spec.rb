# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webflow::AutoSyncService, type: :service do
  let(:user) { create(:user) }
  let(:wrs) { create(:window_schedule_repair, user: user, is_draft: true) }
  let(:service) { described_class.new(wrs: wrs) }

  describe '#call' do
    context 'when syncing draft WRS without webflow_item_id' do
      it 'creates a new item in Webflow' do
        mock_item_service = instance_double(Webflow::ItemService)
        allow(Webflow::ItemService).to receive(:new).and_return(mock_item_service)
        allow(mock_item_service).to receive(:create_item).with(anything, anything).and_return({ 'id' => 'webflow-123' })

        result = service.call

        expect(result[:success]).to be true
        expect(result[:action]).to eq('created')
        expect(result[:webflow_item_id]).to eq('webflow-123')
      end
    end

    context 'when syncing draft WRS with webflow_item_id' do
      before { wrs.update!(webflow_item_id: 'webflow-123') }

      it 'updates existing item in Webflow' do
        mock_item_service = instance_double(Webflow::ItemService)
        allow(Webflow::ItemService).to receive(:new).and_return(mock_item_service)
        allow(mock_item_service).to receive(:update_item).and_return(true)

        result = service.call

        expect(result[:success]).to be true
        expect(result[:action]).to eq('updated')
      end
    end

    context 'when WRS is published' do
      before { wrs.update!(is_draft: false, webflow_item_id: 'webflow-123') }

      it 'does not sync published WRS' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:reason]).to eq('not_draft')
      end
    end

    context 'when WRS is deleted' do
      before { wrs.soft_delete! }

      it 'does not sync deleted WRS' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:reason]).to eq('record_deleted')
      end
    end

    context 'when WRS has missing required fields' do
      before { wrs.update_column(:name, nil) }

      it 'does not sync WRS with invalid data' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:reason]).to eq('invalid_data')
      end
    end

    context 'when Webflow API returns an error' do
      it 'handles WebflowApiError gracefully' do
        mock_item_service = instance_double(Webflow::ItemService)
        allow(Webflow::ItemService).to receive(:new).and_return(mock_item_service)

        error = WebflowApiError.new('API Error', 500, 'Internal Server Error')
        allow(mock_item_service).to receive(:create_item).and_raise(error)

        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq('API Error')
        expect(result[:status_code]).to eq(500)
      end
    end
  end

  describe 'error handling' do
    it 'handles network errors gracefully' do
      mock_item_service = instance_double(Webflow::ItemService)
      allow(Webflow::ItemService).to receive(:new).and_return(mock_item_service)
      allow(mock_item_service).to receive(:create_item).and_raise(StandardError, 'Network error')

      result = service.call

      expect(result[:success]).to be false
      expect(result[:error]).to eq('Network error')
    end
  end
end
