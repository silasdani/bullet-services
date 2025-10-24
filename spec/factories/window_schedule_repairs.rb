# frozen_string_literal: true

FactoryBot.define do
  factory :window_schedule_repair do
    association :user
    name { Faker::Company.name }
    address { Faker::Address.street_address }
    flat_number { Faker::Address.building_number }
    details { Faker::Lorem.paragraph }
    status { :pending }
    total_vat_excluded_price { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    total_vat_included_price { total_vat_excluded_price * 1.2 }
    grand_total { total_vat_included_price }

    trait :with_windows do
      after(:create) do |wrs|
        create_list(:window, 2, window_schedule_repair: wrs)
      end
    end

    trait :published do
      is_draft { false }
      last_published { Time.current }
    end

    trait :draft do
      is_draft { true }
    end

    trait :archived do
      is_archived { true }
    end
  end
end
