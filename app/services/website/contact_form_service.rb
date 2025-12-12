# frozen_string_literal: true

module Website
  class ContactFormService < ApplicationService
    attr_accessor :name, :email, :message

    def initialize(params)
      super()
      @name = params[:name]
      @email = params[:email]
      @message = params[:message]
    end

    def call
      return self unless valid?

      send_notification_email
      self
    end

    private

    def valid?
      if name.blank?
        add_error('Name is required')
        return false
      end

      if email.blank?
        add_error('Email is required')
        return false
      end

      unless email.match?(/\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)
        add_error('Email format is invalid')
        return false
      end

      if message.blank?
        add_error('Message is required')
        return false
      end

      true
    end

    def send_notification_email
      recipient_email = ENV.fetch('CONTACT_EMAIL', 'office@bulletservices.co.uk')

      MailerSendEmailService.new(
        to: recipient_email,
        subject: "New Contact Form Submission from #{name}",
        html: build_html_content,
        text: build_text_content
      ).call
    rescue StandardError => e
      log_error("Failed to send contact form email: #{e.message}")
      add_error('Failed to send email. Please try again later.')
    end

    def build_html_content
      <<~HTML
        <h2>New Contact Form Submission</h2>
        <p><strong>Name:</strong> #{name}</p>
        <p><strong>Email:</strong> #{email}</p>
        <p><strong>Message:</strong></p>
        <p>#{message.gsub("\n", '<br>')}</p>
      HTML
    end

    def build_text_content
      <<~TEXT
        New Contact Form Submission

        Name: #{name}
        Email: #{email}
        Message:
        #{message}
      TEXT
    end
  end
end
