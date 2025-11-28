# frozen_string_literal: true

class FreshbooksToken < ApplicationRecord
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :token_expires_at, presence: true
  validates :business_id, presence: true, uniqueness: true

  def expired?
    token_expires_at < Time.current
  end

  def expires_soon?(buffer_seconds: 300)
    token_expires_at < Time.current + buffer_seconds
  end

  def self.current
    order(created_at: :desc).first
  end
end
