# frozen_string_literal: true

require 'csv'

class InvoiceCsvImportService < ApplicationService
  attr_accessor :csv_file, :user, :import_results

  def initialize(csv_file:, user:)
    super()
    @csv_file = csv_file
    @user = user
    @import_results = {
      total_rows: 0,
      successful_imports: 0,
      failed_imports: 0,
      errors: []
    }
  end

  def call
    return add_error('CSV file is required') if csv_file.blank?
    return add_error('User is required') if user.blank?

    with_error_handling do
      process_csv_file
    end

    self
  end

  private

  def process_csv_file
    log_info("Starting CSV import for user: #{user.email}")

    csv_data = parse_csv_file
    return if csv_data.blank?

    @import_results[:total_rows] = csv_data.length

    with_transaction do
      csv_data.each_with_index do |row, index|
        process_row(row, index + 2) # +2 because CSV is 1-indexed and we skip header
      end
    end

    log_info("CSV import completed. Success: #{@import_results[:successful_imports]}, Failed: #{@import_results[:failed_imports]}")
  end

  def parse_csv_file
    CSV.parse(csv_file.read, headers: true, header_converters: :symbol)
  rescue CSV::MalformedCSVError => e
    add_error("Invalid CSV format: #{e.message}")
    nil
  rescue StandardError => e
    add_error("Error reading CSV file: #{e.message}")
    nil
  end

  def process_row(row, row_number)
    invoice_attributes = map_csv_row_to_attributes(row)

    if invoice_attributes.blank?
      @import_results[:failed_imports] += 1
      @import_results[:errors] << "Row #{row_number}: Invalid data format"
      return
    end

    invoice = Invoice.new(invoice_attributes)

    if invoice.save
      @import_results[:successful_imports] += 1
      log_info("Successfully imported invoice: #{invoice.name}")
    else
      @import_results[:failed_imports] += 1
      error_message = "Row #{row_number}: #{invoice.errors.full_messages.join(', ')}"
      @import_results[:errors] << error_message
      log_error("Failed to import invoice: #{error_message}")
    end
  end

  def map_csv_row_to_attributes(row)
    {
      name: row[:name]&.strip,
      slug: row[:slug]&.strip,
      webflow_item_id: row[:webflow_item_id]&.strip,
      is_archived: parse_boolean(row[:is_archived]),
      is_draft: parse_boolean(row[:is_draft]),
      webflow_created_on: row[:webflow_created_on]&.strip,
      webflow_published_on: row[:webflow_published_on]&.strip,
      freshbooks_client_id: row[:freshbooks_client_id]&.strip,
      job: row[:job]&.strip,
      wrs_link: row[:wrs_link]&.strip,
      included_vat_amount: parse_decimal(row[:included_vat_amount]),
      excluded_vat_amount: parse_decimal(row[:excluded_vat_amount]),
      status_color: row[:status_color]&.strip,
      status: row[:status]&.strip,
      final_status: row[:final_status]&.strip,
      invoice_pdf_link: row[:invoice_pdf_link]&.strip
    }.compact
  end

  def parse_boolean(value)
    return nil if value.blank?

    case value.to_s.downcase.strip
    when 'true', '1', 'yes', 'y'
      true
    when 'false', '0', 'no', 'n'
      false
    end
  end

  def parse_decimal(value)
    return nil if value.blank?

    # Remove currency symbols and commas
    cleaned_value = value.to_s.gsub(/[£$€,\s]/, '')

    # Convert to decimal
    BigDecimal(cleaned_value)
  rescue ArgumentError
    nil
  end
end
