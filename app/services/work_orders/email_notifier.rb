# frozen_string_literal: true

module WorkOrders
  # Service for sending admin notification emails for work order decisions
  class EmailNotifier
    def initialize(work_order, first_name, last_name, email)
      @work_order = work_order
      @first_name = first_name
      @last_name = last_name
      @email = email
    end

    def send_accept_email(invoice, fb_client_data)
      Rails.logger.info(
        "Sending work order ACCEPT email for work_order_id=#{work_order.id}, " \
        "client_email=#{email}, invoice_id=#{invoice.id}"
      )
      WorkOrderMailer.with(
        work_order: work_order,
        first_name: first_name,
        last_name: last_name,
        email: email,
        invoice: invoice,
        fb_client_data: fb_client_data
      ).work_order_accept_notification.deliver_now
    end

    def send_decline_email
      Rails.logger.info(
        "Sending work order DECLINE email for work_order_id=#{work_order.id}, " \
        "client_email=#{email}"
      )
      WorkOrderMailer.with(
        work_order: work_order,
        first_name: first_name,
        last_name: last_name,
        email: email
      ).work_order_decline_notification.deliver_now
    end

    private

    attr_reader :work_order, :first_name, :last_name, :email
  end
end
