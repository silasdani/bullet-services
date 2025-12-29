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
      ContactMailer.with(
        name: name,
        email: email,
        message: message
      ).contact_form_submission.deliver_now
    rescue StandardError => e
      log_error("Failed to send contact form email: #{e.message}")
      add_error('Failed to send email. Please try again later.')
    end
  end
end
