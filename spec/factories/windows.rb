# frozen_string_literal: true

FactoryBot.define do
  factory :window do
    association :window_schedule_repair
    location { Faker::Lorem.word }

    trait :with_tools do
      after(:create) do |window|
        create_list(:tool, 2, window: window)
      end
    end
  end
end
