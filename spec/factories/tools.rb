# frozen_string_literal: true

FactoryBot.define do
  factory :tool do
    association :window
    name { Faker::Commerce.product_name }
    price { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
  end
end
