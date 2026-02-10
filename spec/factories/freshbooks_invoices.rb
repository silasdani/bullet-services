# frozen_string_literal: true

FactoryBot.define do
  factory :freshbooks_invoice do
    association :invoice

    freshbooks_id { "fb-#{SecureRandom.hex(6)}" }
    freshbooks_client_id { "client-#{SecureRandom.hex(4)}" }
    invoice_number { "INV-#{SecureRandom.hex(3)}" }
    status { 'draft' }
    amount { 0 }
    amount_outstanding { amount }
    date { Date.current }
    due_date { Date.current + 14.days }
    currency_code { 'GBP' }
    notes { nil }
    pdf_url { nil }
    raw_data { {} }
  end
end

