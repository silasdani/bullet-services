# frozen_string_literal: true

module Freshbooks
  class Clients < BaseClient
    def list(page: 1, per_page: 100)
      path = build_path('users/clients')
      response = make_request(
        :get,
        path,
        query: {
          page: page,
          per_page: per_page
        }
      )

      {
        clients: response.dig('response', 'result', 'clients') || [],
        page: response.dig('response', 'result', 'page') || page,
        pages: response.dig('response', 'result', 'pages') || 1,
        total: response.dig('response', 'result', 'total') || 0
      }
    end

    def get(client_id)
      path = build_path("users/clients/#{client_id}")
      response = make_request(:get, path)
      response.dig('response', 'result', 'client')
    end

    def create(params)
      path = build_path('users/clients')
      payload = {
        client: {
          email: params[:email],
          fname: params[:first_name],
          lname: params[:last_name],
          organization: params[:organization],
          phone: params[:phone],
          p_street: params[:address],
          p_city: params[:city],
          p_province: params[:province],
          p_code: params[:postal_code],
          p_country: params[:country]
        }.compact
      }

      response = make_request(:post, path, body: payload.to_json)
      response.dig('response', 'result', 'client')
    end

    def update(client_id, params)
      path = build_path("users/clients/#{client_id}")
      payload = {
        client: params.slice(:email, :fname, :lname, :organization, :phone,
                             :p_street, :p_city, :p_province, :p_code, :p_country).compact
      }

      response = make_request(:put, path, body: payload.to_json)
      response.dig('response', 'result', 'client')
    end
  end
end
