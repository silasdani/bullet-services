# frozen_string_literal: true

class WindowSerializer < ActiveModel::Serializer
  attributes :id,
             :location,
             :created_at,
             :updated_at,
             :image,                # backwards-compatible field (first image)
             :images,               # array of all image URLs
             :effective_image_url,  # preferred URL (ActiveStorage if present)
             :effective_image_urls, # array of all effective image URLs
             :image_name

  # Hide prices for contractors, but allow tools (needed for work descriptions)
  attribute :tools
  attribute :total_price, if: :show_prices?

  def tools
    return [] unless object.respond_to?(:tools)

    serialize_tools(tools_list)
  rescue StandardError => e
    Rails.logger.error "Error loading tools in window serializer: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    []
  end

  def total_price
    return nil if scope&.contractor?

    begin
      object.total_price
    rescue StandardError => e
      Rails.logger.error "Error calculating total_price in window serializer: #{e.message}"
      nil
    end
  end

  # Backwards-compatible: return the effective image URL (first image)
  def image
    safe_call { object.effective_image_url }
  end

  # Return array of all image URLs
  def images
    safe_call { object.image_urls }
  end

  def image_url
    safe_call { object.image_url }
  end

  def effective_image_url
    safe_call { object.effective_image_url }
  end

  def effective_image_urls
    safe_call { object.effective_image_urls }
  end

  def image_name
    safe_call { object.image_name }
  end

  def show_prices?
    !scope&.contractor?
  end

  private

  def tools_list
    object.association(:tools).loaded? ? object.tools.to_a : object.tools.load.to_a
  end

  def serialize_tools(list)
    list.map { |t| ToolSerializer.new(t, scope: scope) }
  end

  def safe_call
    yield
  rescue StandardError => e
    Rails.logger.error "Error serializing window image field: #{e.message}"
    nil
  end
end
