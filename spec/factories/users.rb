# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { :contractor }
    confirmed_at { Time.current }

    trait :admin do
      role { :admin }
    end

    trait :contractor do
      role { :contractor }
    end

    trait :surveyor do
      role { :surveyor }
    end

    trait :general_contractor do
      role { :general_contractor }
    end

    trait :supervisor do
      role { :supervisor }
    end
  end
end
