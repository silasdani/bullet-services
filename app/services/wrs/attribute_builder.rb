# frozen_string_literal: true

module Wrs
  class AttributeBuilder
    def self.build_wrs_attributes(field_data, wrs_data)
      {
        **build_basic_wrs_attributes(field_data, wrs_data),
        **build_pricing_wrs_attributes(field_data),
        **build_status_wrs_attributes(field_data),
        **build_webflow_wrs_attributes(field_data, wrs_data)
      }
    end

    def self.build_basic_wrs_attributes(field_data, wrs_data)
      {
        name: field_data['name'] || "WRS #{wrs_data['id']}",
        address: field_data['project-summary'],
        flat_number: field_data['flat-number'],
        details: field_data['project-summary'],
        reference_number: extract_reference_number(field_data),
        slug: field_data['slug'] || "wrs-#{wrs_data['id']}"
      }
    end

    def self.build_pricing_wrs_attributes(field_data)
      {
        total_vat_included_price: extract_price(field_data, 'total-incl-vat'),
        total_vat_excluded_price: extract_price(field_data, 'total-exc-vat'),
        grand_total: extract_price(field_data, 'grand-total')
      }
    end

    def self.build_status_wrs_attributes(field_data)
      status_color = field_data['accepted-declined']
      {
        status: map_status_color_to_status(status_color),
        status_color: status_color
      }
    end

    def self.build_webflow_wrs_attributes(field_data, wrs_data)
      {
        last_published: wrs_data['lastPublished'],
        is_draft: wrs_data['isDraft'],
        is_archived: wrs_data['isArchived'],
        webflow_main_image_url: extract_main_image_url(field_data)
      }
    end

    def self.extract_reference_number(field_data)
      WebflowDataExtractor.wf_first(field_data, 'reference-number', 'reference_number', 'referenceNumber')
    end

    def self.extract_price(field_data, key)
      value = WebflowDataExtractor.wf_first(field_data, key, key.gsub('-', '_'), key.camelize)
      value.to_f
    end

    def self.extract_main_image_url(field_data)
      main_image = field_data['main-project-image']
      main_image && main_image['url']
    end

    def self.map_status_color_to_status(status_color)
      case status_color&.downcase
      when '#024900' # Green - accepted
        'approved'
      when '#750002', '#740000' # Dark colors - rejected
        'rejected'
      else
        'pending'
      end
    end
  end
end
