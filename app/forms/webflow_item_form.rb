# frozen_string_literal: true

class WebflowItemForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Core fields
  attribute :name, :string
  attribute :slug, :string

  # Basic information
  attribute :reference_number, :string
  attribute :project_summary, :string
  attribute :flat_number, :string

  # Window details (up to 5 windows)
  attribute :window_location, :string
  attribute :window_1_items_2, :string
  attribute :window_1_items_prices_3, :string
  attribute :window_1_image, :string
  attribute :window_2_location, :string
  attribute :window_2_items_2, :string
  attribute :window_2_items_prices_3, :string
  attribute :window_2_image, :string
  attribute :window_3_location, :string
  attribute :window_3_items, :string
  attribute :window_3_items_prices, :string
  attribute :window_3_image, :string
  attribute :window_4_location, :string
  attribute :window_4_items, :string
  attribute :window_4_items_prices, :string
  attribute :window_4_image, :string
  attribute :window_5_location, :string
  attribute :window_5_items, :string
  attribute :window_5_items_prices, :string
  attribute :window_5_image, :string

  # Financial information
  attribute :total_incl_vat, :decimal, default: 0
  attribute :total_exc_vat, :decimal, default: 0
  attribute :grand_total, :decimal, default: 0

  # Status
  attribute :accepted_declined, :string, default: "#000000"
  attribute :accepted_decline, :string, default: ""

  # Legacy field mapping
  attribute :address, :string

  validates :name, presence: true
  validates :slug, presence: true, format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, alphanumeric with hyphens only" }

  def self.from_params(params)
    field_data = params[:fieldData] || params.dig(:webflow, :fieldData)
    return new if field_data.blank?

    new(
      name: field_data["name"],
      slug: field_data["slug"],
      reference_number: field_data["reference-number"],
      project_summary: field_data["project-summary"],
      flat_number: field_data["flat-number"],
      window_location: field_data["window-location"],
      window_1_items_2: field_data["window-1-items-2"],
      window_1_items_prices_3: field_data["window-1-items-prices-3"],
      window_1_image: field_data["window-1-image"],
      window_2_location: field_data["window-2-location"],
      window_2_items_2: field_data["window-2-items-2"],
      window_2_items_prices_3: field_data["window-2-items-prices-3"],
      window_2_image: field_data["window-2-image"],
      window_3_location: field_data["window-3-location"],
      window_3_items: field_data["window-3-items"],
      window_3_items_prices: field_data["window-3-items-prices"],
      window_3_image: field_data["window-3-image"],
      window_4_location: field_data["window-4-location"],
      window_4_items: field_data["window-4-items"],
      window_4_items_prices: field_data["window-4-items-prices"],
      window_4_image: field_data["window-4-image"],
      window_5_location: field_data["window-5-location"],
      window_5_items: field_data["window-5-items"],
      window_5_items_prices: field_data["window-5-items-prices"],
      window_5_image: field_data["window-5-image"],
      total_incl_vat: field_data["total-incl-vat"],
      total_exc_vat: field_data["total-exc-vat"],
      grand_total: field_data["grand-total"],
      accepted_declined: field_data["accepted-declined"],
      accepted_decline: field_data["accepted-decline"],
      address: field_data["address"]
    )
  end

  def to_webflow_format
    {
      "name" => name,
      "slug" => slug,
      "reference-number" => reference_number || "",
      "project-summary" => project_summary || address || "",
      "flat-number" => flat_number || "",
      "window-location" => window_location || "",
      "window-1-items-2" => window_1_items_2 || "",
      "window-1-items-prices-3" => window_1_items_prices_3 || "",
      "window-1-image" => window_1_image || "",
      "window-2-location" => window_2_location || "",
      "window-2-items-2" => window_2_items_2 || "",
      "window-2-items-prices-3" => window_2_items_prices_3 || "",
      "window-2-image" => window_2_image || "",
      "window-3-location" => window_3_location || "",
      "window-3-items" => window_3_items || "",
      "window-3-items-prices" => window_3_items_prices || "",
      "window-3-image" => window_3_image || "",
      "window-4-location" => window_4_location || "",
      "window-4-items" => window_4_items || "",
      "window-4-items-prices" => window_4_items_prices || "",
      "window-4-image" => window_4_image || "",
      "window-5-location" => window_5_location || "",
      "window-5-items" => window_5_items || "",
      "window-5-items-prices" => window_5_items_prices || "",
      "window-5-image" => window_5_image || "",
      "total-incl-vat" => total_incl_vat || 0,
      "total-exc-vat" => total_exc_vat || 0,
      "grand-total" => grand_total || 0,
      "accepted-declined" => accepted_declined || "#000000",
      "accepted-decline" => accepted_decline || ""
    }
  end
end
