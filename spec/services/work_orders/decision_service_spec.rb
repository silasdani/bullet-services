# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrders::DecisionService do
  let(:work_order) { create(:work_order) }
  let(:email) { 'client@example.com' }

  describe '#call' do
    context 'when decision is accept' do
      it 'creates WorkOrderDecision, FreshBooks client and invoice and marks work order as approved' do
        allow(Freshbooks::Clients).to receive(:new).and_return(double(create: { 'id' => '123' }))
        allow_any_instance_of(Invoice)
          .to receive(:create_in_freshbooks!)
          .and_return({ pdf_url: 'https://example.com/invoice.pdf' })
        allow(MailerSendEmailService).to receive(:new).and_return(double(call: true))

        service = described_class.new(
          work_order: work_order,
          first_name: 'John',
          last_name: 'Doe',
          email: email,
          decision: 'accept'
        )

        result = service.call

        expect(result).to be_success
        expect(work_order.reload.status).to eq('approved')
        expect(work_order.work_order_decision).to be_present
        expect(work_order.work_order_decision.decision).to eq('approved')
      end
    end

    context 'when decision is decline' do
      it 'creates WorkOrderDecision, marks work order as rejected and sends admin email' do
        allow(MailerSendEmailService).to receive(:new).and_return(double(call: true))

        service = described_class.new(
          work_order: work_order,
          first_name: 'John',
          last_name: 'Doe',
          email: email,
          decision: 'decline'
        )

        result = service.call

        expect(result).to be_success
        expect(work_order.reload.status).to eq('rejected')
        expect(work_order.work_order_decision).to be_present
        expect(work_order.work_order_decision.decision).to eq('rejected')
      end
    end
  end
end
