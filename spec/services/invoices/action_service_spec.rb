# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::ActionService do
  let(:invoice) { create(:invoice) }
  let(:fb_invoice) do
    create(:freshbooks_invoice, invoice: invoice, freshbooks_id: 'fb-1', amount: 100, amount_outstanding: 100)
  end

  before do
    fb_invoice
  end

  describe '#call' do
    context 'when action is send' do
      it 'sends invoice via FreshBooks' do
        client = double('Freshbooks::Invoices', send_by_email: true)
        allow(Freshbooks::Invoices).to receive(:new).and_return(client)

        service = described_class.new(invoice: invoice, action: 'send')
        result = service.call

        expect(result).to be_success
      end
    end

    context 'when action is void' do
      it 'voids invoice in FreshBooks and updates local records' do
        client = double('Freshbooks::Invoices', update: true)
        allow(Freshbooks::Invoices).to receive(:new).and_return(client)

        service = described_class.new(invoice: invoice, action: 'void')
        result = service.call

        expect(result).to be_success
        expect(invoice.reload.final_status).to eq('void')
      end
    end

    context 'when action is discount' do
      it 'applies discount to FreshBooks invoice' do
        client = double('Freshbooks::Invoices', update: true)
        allow(Freshbooks::Invoices).to receive(:new).and_return(client)

        service = described_class.new(invoice: invoice, action: 'discount', discount_amount: 10)
        result = service.call

        expect(result).to be_success
      end
    end
  end
end
