# frozen_string_literal: true

module Freshbooks
  module Invoices
    # Module for building invoice line items
    module LineBuilder
      def build_lines(lines_data)
        lines_data.map { |line| build_single_line(line) }
      end

      private

      def build_single_line(line)
        line_item = build_base_line_item(line)
        apply_tax_settings(line_item, line)
        line_item.compact
      end

      def build_base_line_item(line)
        {
          name: line[:name],
          description: line[:description],
          qty: extract_quantity(line),
          unit_cost: build_unit_cost(line),
          type: line[:type] || 0
        }
      end

      def extract_quantity(line)
        line[:quantity] || line[:qty] || 1
      end

      def build_unit_cost(line)
        {
          amount: line[:cost] || line[:unit_cost],
          code: line[:currency] || 'USD'
        }
      end

      def apply_tax_settings(line_item, line)
        if tax_included?(line)
          zero_tax_amounts(line_item)
        elsif line[:tax_amount1].present?
          set_custom_tax_amounts(line_item, line)
        end
      end

      def tax_included?(line)
        [true, 'yes'].include?(line[:tax_included])
      end

      def zero_tax_amounts(line_item)
        line_item[:tax_amount1] = '0'
        line_item[:tax_amount2] = '0'
      end

      def set_custom_tax_amounts(line_item, line)
        line_item[:tax_amount1] = line[:tax_amount1]
        line_item[:tax_amount2] = line[:tax_amount2] if line[:tax_amount2].present?
      end
    end
  end
end
