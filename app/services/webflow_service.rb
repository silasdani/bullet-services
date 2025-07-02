# frozen_string_literal: true

class WebflowService
  include HTTParty

  base_uri 'https://api.webflow.com'

  def initialize(quotation)
    @quotation = quotation
    @api_key = Rails.application.credentials.webflow_api_key
    @collection_id = Rails.application.credentials.webflow_collection_id
  end

  def send_quotation
    response = self.class.post(
      "/collections/#{@collection_id}/items",
      headers: headers,
      body: quotation_data.to_json
    )

    if response.success?
      Rails.logger.info "Quotation #{@quotation.id} sent to Webflow successfully"
      response
    else
      Rails.logger.error "Failed to send quotation to Webflow: #{response.body}"
      raise "Webflow API Error: #{response.body}"
    end
  end

  private

  def headers
    {
      'Authorization' => "Bearer #{@api_key}",
      'accept-version' => '1.0.0',
      'Content-Type' => 'application/json'
    }
  end

  def quotation_data
    {
      fields: {
        name: @quotation.address,
        _archived: false,
        _draft: false,
        address: @quotation.address,
        details: @quotation.details,
        price: @quotation.price.to_f,
        status: @quotation.status,
        'client-name': @quotation.client_name,
        'client-phone': @quotation.client_phone,
        'client-email': @quotation.client_email,
        # Adaugă URL-urile imaginilor dacă sunt necesare
        images: @quotation.images.map { |img| Rails.application.routes.url_helpers.url_for(img) }
      }
    }
  end
end