# frozen_string_literal: true

# Custom ActionMailer delivery method for MailerSend
class MailerSendDeliveryMethod
  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    MailerSendEmailService.new(
      to: mail.to.first,
      subject: mail.subject,
      html: mail.html_part&.body&.to_s || mail.body&.to_s,
      text: mail.text_part&.body&.to_s || extract_text_from_html(mail.body&.to_s),
      from_email: mail.from&.first || ENV.fetch('MAILERSEND_FROM_EMAIL', 'no-reply@example.com'),
      from_name: extract_name_from_from_header(mail[:from]) || ENV.fetch('MAILERSEND_FROM_NAME', 'Bullet Services')
    ).call
  end

  private

  def extract_text_from_html(html)
    return nil if html.blank?

    html.gsub(%r{</?[^>]*>}, '').strip
  end

  def extract_name_from_from_header(from_header)
    return nil unless from_header

    from_header.value.match(/^(.+?)\s*<.+>$/)&.captures&.first
  end
end
