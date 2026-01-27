# frozen_string_literal: true

class SendFcmNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, title, body, data = {})
    user = User.find_by(id: user_id)
    return unless user&.fcm_token.present?

    Fcm::SendNotificationService.new(
      user: user,
      title: title,
      body: body,
      data: data
    ).call
  end
end
