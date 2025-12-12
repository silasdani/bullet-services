# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  # Default from for Rails mailers; should be a verified sender in your MailerSend (or SMTP) account.
  # You can override per-mailer or per-email as needed.
  default from: ENV.fetch('MAILERSEND_FROM_EMAIL', 'no-reply@example.com')
  layout 'mailer'
end
