# frozen_string_literal: true

class Avo::Fields::InvoiceStatusBadgeField::IndexComponent < Avo::Fields::IndexComponent
  def invoice
    @resource&.record
  end

  def status
    return 'draft' unless invoice

    invoice.final_status || invoice.status || 'draft'
  end

  def badge_class
    return 'bg-gray-500 text-white' unless invoice

    case status.downcase
    when 'paid'
      'bg-emerald-500 text-white'
    when 'sent', 'viewed'
      'bg-blue-500 text-white'
    when 'voided'
      'bg-red-500 text-white'
    else
      'bg-gray-500 text-white' # draft and unknown
    end
  end
end
