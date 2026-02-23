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
      html: extract_html_content(mail),
      text: extract_text_content(mail),
      from_email: extract_from_email(mail),
      from_name: extract_from_name(mail)
    ).call
  end

  private

  def extract_html_content(mail)
    mail.html_part&.body&.to_s || mail.body&.to_s
  end

  def extract_text_content(mail)
    mail.text_part&.body&.to_s || extract_text_from_html(mail.body&.to_s)
  end

  def extract_from_email(mail)
    mail.from&.first || ENV.fetch('MAILERSEND_FROM_EMAIL', 'no-reply@bulletservices.co.uk')
  end

  def extract_from_name(mail)
    extract_name_from_from_header(mail[:from]) || ENV.fetch('MAILERSEND_FROM_NAME', 'Bullet Services')
  end

  def extract_text_from_html(html)
    return nil if html.blank?

    html.gsub(%r{</?[^>]*>}, '').strip
  end

  def extract_name_from_from_header(from_header)
    return nil unless from_header

    from_header.value.match(/^(.+?)\s*<.+>$/)&.captures&.first
  end
end
