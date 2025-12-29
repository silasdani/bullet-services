# frozen_string_literal: true

module Wrs
  # Service for sending admin notification emails for WRS decisions
  class EmailNotifier
    def initialize(window_schedule_repair, first_name, last_name, email)
      @window_schedule_repair = window_schedule_repair
      @first_name = first_name
      @last_name = last_name
      @email = email
    end

    def send_accept_email(invoice, fb_client_data)
      WrsMailer.with(
        window_schedule_repair: window_schedule_repair,
        first_name: first_name,
        last_name: last_name,
        email: email,
        invoice: invoice,
        fb_client_data: fb_client_data
      ).wrs_accept_notification.deliver_now
    end

    def send_decline_email
      WrsMailer.with(
        window_schedule_repair: window_schedule_repair,
        first_name: first_name,
        last_name: last_name,
        email: email
      ).wrs_decline_notification.deliver_now
    end

    private

    attr_reader :window_schedule_repair, :first_name, :last_name, :email
  end
end
