# frozen_string_literal: true

namespace :invoices do
  desc 'Import invoices from Webflow CSV file'
  task import_webflow_csv: :environment do
    require 'csv'
    require 'uri'

    csv_path = Rails.root.join('lib', 'assets', 'Bullet - Invoices.csv')

    unless File.exist?(csv_path)
      puts "❌ CSV file not found at: #{csv_path}"
      exit 1
    end

    puts '🔄 Starting Webflow invoice CSV import...'
    puts "📄 Reading CSV from: #{csv_path}"
    puts '=' * 80

    stats = {
      total_rows: 0,
      created: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      pdfs_mirrored: 0,
      pdfs_failed: 0,
      errors: []
    }

    begin
      csv_content = File.read(csv_path)
      csv_data = CSV.parse(csv_content, headers: true, header_converters: :symbol)

      stats[:total_rows] = csv_data.length
      puts "📊 Found #{stats[:total_rows]} rows to process"
      puts '=' * 80

      csv_data.each_with_index do |row, index|
        row_number = index + 2 # +2 because CSV is 1-indexed and we skip header
        process_row(row, row_number, stats)
      end

      print_summary(stats)
    rescue CSV::MalformedCSVError => e
      puts "❌ Invalid CSV format: #{e.message}"
      exit 1
    rescue StandardError => e
      puts "❌ Unexpected error: #{e.message}"
      puts e.backtrace.first(10).join("\n")
      exit 1
    end
  end

  def process_row(row, row_number, stats)
    print "Processing row #{row_number}... "

    begin
      invoice_attributes = map_csv_row_to_attributes(row)

      # Validate required fields
      if invoice_attributes.blank? || missing_required_fields?(invoice_attributes)
        stats[:skipped] += 1
        missing_fields = get_missing_required_fields(invoice_attributes)
        error_msg = "Skipped (missing required fields: #{missing_fields.join(', ')})"
        stats[:errors] << "Row #{row_number}: #{error_msg}"
        puts "⏭️  #{error_msg}"
        return
      end

      # Find existing invoice by webflow_item_id or slug
      invoice = find_or_initialize_invoice(invoice_attributes)

      if invoice.new_record?
        if invoice.save
          stats[:created] += 1
          print '✅ Created'
        else
          stats[:failed] += 1
          error_msg = "Failed to create: #{invoice.errors.full_messages.join(', ')}"
          stats[:errors] << "Row #{row_number}: #{error_msg}"
          puts "❌ #{error_msg}"
          return
        end
      elsif invoice.update(invoice_attributes.except(:slug, :webflow_item_id))
        stats[:updated] += 1
        print '🔄 Updated'
      else
        stats[:failed] += 1
        error_msg = "Failed to update: #{invoice.errors.full_messages.join(', ')}"
        stats[:errors] << "Row #{row_number}: #{error_msg}"
        puts "❌ #{error_msg}"
        return
      end

      # Handle PDF mirroring
      pdf_url = extract_pdf_url(row)
      if pdf_url.present?
        if mirror_pdf(invoice, pdf_url)
          stats[:pdfs_mirrored] += 1
          puts ' + PDF mirrored'
        else
          stats[:pdfs_failed] += 1
          puts ' + PDF mirroring failed'
        end
      else
        puts ' (no PDF)'
      end
    rescue StandardError => e
      stats[:failed] += 1
      error_msg = "Row #{row_number}: #{e.class} - #{e.message}"
      stats[:errors] << error_msg
      puts "❌ #{error_msg}"
    end
  end

  def map_csv_row_to_attributes(row)
    {
      name: clean_string(row[:name]),
      slug: clean_string(row[:slug]),
      webflow_collection_id: clean_string(row[:collection_id]),
      webflow_item_id: clean_string(row[:item_id]),
      is_archived: parse_boolean(row[:archived]),
      is_draft: parse_boolean(row[:draft]),
      webflow_created_on: clean_string(row[:created_on]),
      webflow_updated_on: clean_string(row[:updated_on]),
      webflow_published_on: clean_string(row[:published_on]),
      job: clean_string(row[:job]),
      freshbooks_client_id: clean_string(row[:client_id]),
      flat_address: clean_string(row[:flataddress]), # CSV converts "Flat/Address" to :flataddress
      generated_by: clean_string(row[:generated_by]),
      excluded_vat_amount: parse_decimal(row[:amount_excl_vat]),
      included_vat_amount: parse_decimal(row[:amount_incl_vat]),
      status_color: clean_string(row[:status_color]),
      status: clean_string(row[:status]),
      final_status: clean_string(row[:final_status]),
      wrs_link: clean_string(row[:wrs_page]),
      invoice_pdf_link: extract_pdf_url(row) # Keep for backward compatibility
    }.compact
  end

  def find_or_initialize_invoice(attributes)
    invoice = Invoice.find_by(webflow_item_id: attributes[:webflow_item_id]) if attributes[:webflow_item_id].present?
    invoice ||= Invoice.find_by(slug: attributes[:slug]) if attributes[:slug].present?
    invoice ||= Invoice.new

    invoice.assign_attributes(attributes)
    invoice
  end

  def extract_pdf_url(row)
    # The CSV column name is ".pdf invoice" with a leading dot and space
    # CSV header_converters :symbol converts to :pdf_invoice (removes dot and space)
    pdf_url = row[:pdf_invoice]
    clean_string(pdf_url)
  end

  def mirror_pdf(invoice, pdf_url)
    return false if pdf_url.blank?

    service = Webflow::PdfMirrorService.new(
      record: invoice,
      source_url: pdf_url,
      attachment_name: :invoice_pdf
    )

    service.call
    service.success?
  rescue StandardError => e
    puts "   PDF mirror error: #{e.message}"
    false
  end

  def clean_string(value)
    return nil if value.nil?

    str = value.to_s.strip
    str.empty? ? nil : str
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

    # Remove currency symbols, commas, and whitespace
    cleaned_value = value.to_s.gsub(/[£$€,\s]/, '')

    # Convert to decimal
    BigDecimal(cleaned_value)
  rescue ArgumentError, TypeError
    nil
  end

  def missing_required_fields?(attributes)
    required_fields = %i[name slug freshbooks_client_id status final_status]
    required_fields.any? { |field| attributes[field].blank? }
  end

  def get_missing_required_fields(attributes)
    required_fields = %i[name slug freshbooks_client_id status final_status]
    required_fields.select { |field| attributes[field].blank? }
  end

  def print_summary(stats)
    puts "\n#{'=' * 80}"
    puts '✨ Import Summary'
    puts '=' * 80
    puts "Total rows processed: #{stats[:total_rows]}"
    puts "✅ Created: #{stats[:created]}"
    puts "🔄 Updated: #{stats[:updated]}"
    puts "⏭️  Skipped: #{stats[:skipped]}"
    puts "❌ Failed: #{stats[:failed]}"
    puts "📄 PDFs mirrored: #{stats[:pdfs_mirrored]}"
    puts "⚠️  PDFs failed: #{stats[:pdfs_failed]}"
    puts '=' * 80

    if stats[:errors].any?
      puts "\n❌ Errors encountered:"
      stats[:errors].each do |error|
        puts "   - #{error}"
      end
    end

    puts "\n✅ Import completed!"
  end

  desc 'Fix invoices with broken PDF attachments (blobs that exist in DB but not in S3)'
  task fix_broken_pdfs: :environment do
    puts 'Checking for invoices with broken PDF attachments...'

    broken_count = 0
    fixed_count = 0
    skipped_count = 0

    Invoice.find_each do |invoice|
      next unless invoice.invoice_pdf.attached?

      blob = invoice.invoice_pdf.blob

      # Check if blob exists in S3
      unless blob.service.exist?(blob.key)
        broken_count += 1
        puts "\n[#{broken_count}] Invoice ##{invoice.id} (#{invoice.slug}) - Broken blob: #{blob.key}"

        if invoice.invoice_pdf_link.present?
          puts "  Attempting to re-download from: #{invoice.invoice_pdf_link}"

          begin
            # Purge the broken attachment
            invoice.invoice_pdf.purge

            # Re-attach from FreshBooks URL
            pdf_data = { url: invoice.invoice_pdf_link }
            Wrs::PdfAttachmentService.new(invoice, pdf_data).call

            if invoice.reload.invoice_pdf.attached?
              # Verify the new blob exists in S3
              new_blob = invoice.invoice_pdf.blob
              if new_blob.service.exist?(new_blob.key)
                fixed_count += 1
                puts "  ✅ Fixed! New blob: #{new_blob.key}"
              else
                puts '  ❌ Still broken - file not in S3 after re-upload'
              end
            else
              puts '  ❌ Failed to re-attach PDF'
            end
          rescue StandardError => e
            puts "  ❌ Error fixing invoice: #{e.class}: #{e.message}"
            puts "     #{e.backtrace.first(3).join("\n     ")}"
          end
        else
          skipped_count += 1
          puts '  ⏭️  Skipped - no invoice_pdf_link available'
        end
      end
    end

    puts "\n#{'=' * 60}"
    puts 'Summary:'
    puts "  Broken blobs found: #{broken_count}"
    puts "  Fixed: #{fixed_count}"
    puts "  Skipped (no PDF link): #{skipped_count}"
    puts '=' * 60
  end

  desc 'List all invoices with broken PDF attachments'
  task list_broken_pdfs: :environment do
    puts 'Scanning for invoices with broken PDF attachments...'
    puts ''

    broken_count = 0

    Invoice.find_each do |invoice|
      next unless invoice.invoice_pdf.attached?

      blob = invoice.invoice_pdf.blob

      unless blob.service.exist?(blob.key)
        broken_count += 1
        puts "[#{broken_count}] Invoice ##{invoice.id}"
        puts "    Slug: #{invoice.slug}"
        puts "    Blob Key: #{blob.key}"
        puts "    PDF Link: #{invoice.invoice_pdf_link || 'N/A'}"
        puts "    Created: #{invoice.created_at}"
        puts ''
      end
    end

    if broken_count.zero?
      puts '✅ No broken PDF attachments found!'
    else
      puts "Found #{broken_count} invoice(s) with broken PDF attachments."
      puts "Run 'rake invoices:fix_broken_pdfs' to attempt to fix them."
    end
  end
end
