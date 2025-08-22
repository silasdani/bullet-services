# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../app/forms/webflow_item_form"

class WebflowItemFormTest < Minitest::Test
  def setup
    @valid_params = {
      fieldData: {
        "name" => "Test Project",
        "slug" => "test-project",
        "reference-number" => "REF-001",
        "project-summary" => "123 Test Street",
        "flat-number" => "15",
        "total-incl-vat" => 1200,
        "total-exc-vat" => 1000,
        "grand-total" => 1200
      }
    }
  end

  def test_creates_form_from_valid_params
    form = WebflowItemForm.from_params(@valid_params)

    assert form.valid?
    assert_equal "Test Project", form.name
    assert_equal "test-project", form.slug
    assert_equal "REF-001", form.reference_number
    assert_equal "123 Test Street", form.project_summary
    assert_equal "15", form.flat_number
    assert_equal 1200, form.total_incl_vat
    assert_equal 1000, form.total_exc_vat
    assert_equal 1200, form.grand_total
  end

  def test_creates_form_from_nested_webflow_params
    nested_params = {
      webflow: {
        fieldData: @valid_params[:fieldData]
      }
    }

    form = WebflowItemForm.from_params(nested_params)
    assert form.valid?
    assert_equal "Test Project", form.name
  end

  def test_handles_missing_fieldData_gracefully
    form = WebflowItemForm.from_params({})
    assert form.valid? # Form is valid even with no data
  end

  def test_validates_required_fields
    form = WebflowItemForm.new
    assert !form.valid?
    assert_includes form.errors[:name], "can't be blank"
    assert_includes form.errors[:slug], "can't be blank"
  end

  def test_validates_slug_format
    form = WebflowItemForm.new(name: "Test", slug: "Invalid Slug")
    assert !form.valid?
    assert_includes form.errors[:slug], "must be lowercase, alphanumeric with hyphens only"
  end

  def test_accepts_valid_slug_format
    form = WebflowItemForm.new(name: "Test", slug: "valid-slug-123")
    assert form.valid?
  end

  def test_maps_address_to_project_summary_when_project_summary_is_empty
    params_with_address = {
      fieldData: {
        "name" => "Test",
        "slug" => "test",
        "address" => "456 Address Lane"
      }
    }

    form = WebflowItemForm.from_params(params_with_address)
    webflow_data = form.to_webflow_format

    assert_equal "456 Address Lane", webflow_data["project-summary"]
  end

  def test_converts_to_webflow_format_correctly
    form = WebflowItemForm.from_params(@valid_params)
    webflow_data = form.to_webflow_format

    assert_equal "Test Project", webflow_data["name"]
    assert_equal "test-project", webflow_data["slug"]
    assert_equal "REF-001", webflow_data["reference-number"]
    assert_equal "123 Test Street", webflow_data["project-summary"]
    assert_equal "15", webflow_data["flat-number"]
    assert_equal 1200, webflow_data["total-incl-vat"]
    assert_equal 1000, webflow_data["total-exc-vat"]
    assert_equal 1200, webflow_data["grand-total"]
  end

  def test_provides_default_values_for_missing_fields
    form = WebflowItemForm.new(name: "Test", slug: "test")
    webflow_data = form.to_webflow_format

    assert_equal "", webflow_data["reference-number"]
    assert_equal "", webflow_data["project-summary"]
    assert_equal "", webflow_data["flat-number"]
    assert_equal 0, webflow_data["total-incl-vat"]
    assert_equal 0, webflow_data["total-exc-vat"]
    assert_equal 0, webflow_data["grand-total"]
    assert_equal "#000000", webflow_data["accepted-declined"]
    assert_equal "", webflow_data["accepted-decline"]
  end
end
