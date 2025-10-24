# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WindowScheduleRepair, type: :model do
  let(:user) { create(:user) }

  before do
    # Mock Webflow credentials for testing
    allow(Rails.application.credentials).to receive(:webflow).and_return({
                                                                           wrs_collection_id: 'test_collection_id'
                                                                         })
  end

  describe 'Webflow auto-sync functionality' do
    describe 'default states' do
      it 'defaults to draft for new WRS' do
        wrs = WindowScheduleRepair.new(
          name: 'Test WRS',
          address: '123 Test Street',
          flat_number: 'Apt 1',
          user: user
        )

        wrs.valid? # Trigger validations

        expect(wrs.is_draft).to be true
        expect(wrs.is_archived).to be false
      end
    end

    describe 'auto-sync conditions' do
      it 'should auto-sync draft WRS' do
        wrs = create(:window_schedule_repair, user: user, is_draft: true)

        expect(wrs.should_auto_sync_to_webflow?).to be true
      end

      it 'should auto-sync unsynced WRS' do
        wrs = create(:window_schedule_repair,
                     user: user,
                     is_draft: false,
                     webflow_item_id: nil)

        expect(wrs.should_auto_sync_to_webflow?).to be true
      end

      it 'should not auto-sync published WRS' do
        wrs = create(:window_schedule_repair,
                     user: user,
                     is_draft: false,
                     webflow_item_id: 'webflow-123')

        expect(wrs.should_auto_sync_to_webflow?).to be false
      end

      it 'should not auto-sync deleted WRS' do
        wrs = create(:window_schedule_repair, user: user, is_draft: true)
        wrs.soft_delete!

        expect(wrs.should_auto_sync_to_webflow?).to be false
      end
    end

    describe 'job queuing' do
      it 'queues auto-sync job when creating WRS' do
        expect do
          create(:window_schedule_repair, user: user, is_draft: true)
        end.to have_enqueued_job(WebflowSyncJob)
      end

      it 'queues auto-sync job when updating draft WRS' do
        wrs = create(:window_schedule_repair, user: user, is_draft: true)

        expect do
          wrs.update!(name: 'Updated Test WRS')
        end.to have_enqueued_job(WebflowSyncJob)
      end

      it 'does not queue auto-sync job when updating published WRS' do
        wrs = create(:window_schedule_repair,
                     user: user,
                     is_draft: false,
                     webflow_item_id: 'webflow-123')

        expect do
          wrs.update!(name: 'Updated Test WRS')
        end.not_to have_enqueued_job(WebflowSyncJob)
      end
    end

    describe 'status methods' do
      describe '#draft?' do
        it 'returns true for draft WRS' do
          wrs = build(:window_schedule_repair, is_draft: true)
          expect(wrs.draft?).to be true
        end

        it 'returns false for published WRS' do
          wrs = build(:window_schedule_repair,
                      is_draft: false,
                      webflow_item_id: '123')
          expect(wrs.draft?).to be false
        end

        it 'returns true for unsynced WRS' do
          wrs = build(:window_schedule_repair,
                      is_draft: false,
                      webflow_item_id: nil)
          expect(wrs.draft?).to be true
        end
      end

      describe '#published?' do
        it 'returns true for published WRS' do
          wrs = build(:window_schedule_repair,
                      is_draft: false,
                      is_archived: false,
                      webflow_item_id: '123')
          expect(wrs.published?).to be true
        end

        it 'returns false for draft WRS' do
          wrs = build(:window_schedule_repair,
                      is_draft: true,
                      is_archived: false,
                      webflow_item_id: '123')
          expect(wrs.published?).to be false
        end

        it 'returns false for archived WRS' do
          wrs = build(:window_schedule_repair,
                      is_draft: false,
                      is_archived: true,
                      webflow_item_id: '123')
          expect(wrs.published?).to be false
        end
      end
    end
  end
end
