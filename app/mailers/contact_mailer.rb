# frozen_string_literal: true

class ContactMailer < ApplicationMailer
  def contact_form_submission
    @name = params[:name]
    @email = params[:email]
    @message = params[:message]

    recipient_email = ENV.fetch('CONTACT_EMAIL', 'office@bulletservices.co.uk')

    mail(
      to: recipient_email,
      subject: "New Contact Form Submission from #{@name}"
    )
  end
end
