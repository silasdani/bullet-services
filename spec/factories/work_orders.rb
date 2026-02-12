# frozen_string_literal: true

FactoryBot.define do
  factory :work_order do
    association :user
    association :building
    name { Faker::Company.name }
    flat_number { Faker::Address.building_number }
    details { Faker::Lorem.paragraph }
    status { :pending }
    total_vat_excluded_price { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    total_vat_included_price { total_vat_excluded_price * 1.2 }

    trait :with_windows do
      after(:create) do |work_order|
        create_list(:window, 2, work_order: work_order)
      end
    end

    trait :published do
      is_draft { false }
    end

    trait :draft do
      is_draft { true }
    end

    trait :archived do
      is_archived { true }
    end
  end
end
