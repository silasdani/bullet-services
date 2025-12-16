# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Wrs::DecisionService do
  let(:wrs) { create(:window_schedule_repair) }
  let(:email) { 'client@example.com' }

  describe '#call' do
    context 'when decision is accept' do
      it 'creates a FreshBooks client and invoice and marks wrs as approved' do
        allow(Freshbooks::Clients).to receive(:new).and_return(double(create: { 'id' => '123' }))
        allow_any_instance_of(Invoice)
          .to receive(:create_in_freshbooks!)
          .and_return({ pdf_url: 'https://example.com/invoice.pdf' })
        allow(Webflow::PdfMirrorService).to receive(:new).and_return(double(call: true))
        allow(MailerSendEmailService).to receive(:new).and_return(double(call: true))

        service = described_class.new(
          window_schedule_repair: wrs,
          first_name: 'John',
          last_name: 'Doe',
          email: email,
          decision: 'accept'
        )

        result = service.call

        expect(result).to be_success
        expect(wrs.reload.status).to eq('approved')
      end
    end

    context 'when decision is decline' do
      it 'marks wrs as rejected and sends admin email' do
        allow(MailerSendEmailService).to receive(:new).and_return(double(call: true))

        service = described_class.new(
          window_schedule_repair: wrs,
          first_name: 'John',
          last_name: 'Doe',
          email: email,
          decision: 'decline'
        )

        result = service.call

        expect(result).to be_success
        expect(wrs.reload.status).to eq('rejected')
      end
    end
  end
end
