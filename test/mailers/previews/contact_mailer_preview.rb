# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/contact_mailer
class ContactMailerPreview < ActionMailer::Preview
  def contact_form_submission
    ContactMailer.with(
      name: 'John Doe',
      email: 'john.doe@example.com',
      message: 'This is a sample message from the contact form. I am interested in your window repair services and would like to schedule a consultation.'
    ).contact_form_submission
  end
end
