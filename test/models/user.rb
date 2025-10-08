class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :window_schedule_repairs

  rails_admin do
    configure :User do
      label "Owner of this ball: "
    end
  end
end
