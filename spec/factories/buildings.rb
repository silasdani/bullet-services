# frozen_string_literal: true

FactoryBot.define do
  factory :building do
    name { Faker::Company.name }
    street { Faker::Address.street_address }
    city { Faker::Address.city }
    zipcode { Faker::Address.zip_code }
    country { Faker::Address.country }
  end
end

