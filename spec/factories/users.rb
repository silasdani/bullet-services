# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { :client }
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
  end
end
