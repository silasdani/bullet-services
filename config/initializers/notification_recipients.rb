# frozen_string_literal: true

module NotificationRecipients
  CONTRACTOR_NOTIFICATION_EMAIL = ENV.fetch(
    'NOTIFICATION_CONTRACTOR_EMAIL',
    ENV.fetch('NOTIFICATION_SUBCONTRACTOR_EMAIL', 'mm@bulletservices.co.uk')
  ).freeze

  def self.contractor_recipient
    User.find_by(email: CONTRACTOR_NOTIFICATION_EMAIL) || User.admin.first
  end
end
