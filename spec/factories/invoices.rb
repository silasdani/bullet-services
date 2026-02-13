# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    association :work_order
    name { "Invoice #{Faker::Company.name}" }
    slug { "invoice-#{SecureRandom.hex(6)}" }

    # Keep validation happy without requiring FreshBooks client.
    generated_by { 'wrs_form' }
    freshbooks_client_id { nil }

    status { 'draft' }
    final_status { 'draft' }
    status_color { '#CCCCCC' }

    included_vat_amount { 0 }
    excluded_vat_amount { 0 }
    is_draft { true }
    is_archived { false }
  end
end
