# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::WorkOrdersController, type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:building) { create(:building) }
  let(:work_order) { create(:work_order, user: user) }

  # Helper method for API authentication using Devise Token Auth
  def auth_headers(user)
    # Ensure user is confirmed
    user.confirm unless user.confirmed?

    # Create a token using Devise Token Auth
    token = user.create_new_auth_token

    {
      'access-token' => token['access-token'],
      'client' => token['client'],
      'token-type' => token['token-type'],
      'expiry' => token['expiry'],
      'uid' => token['uid'],
      'Content-Type' => 'application/json'
    }
  end

  describe 'GET /api/v1/work_orders' do
    context 'when user is authenticated' do
      it 'returns a successful response' do
        get api_v1_work_orders_path, headers: auth_headers(user)
        expect(response).to have_http_status(:success), response.body
      end

      it 'returns work orders data' do
        work_order # Create the record
        get api_v1_work_orders_path, headers: auth_headers(user)
        expect(response.body).to include('data')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get api_v1_work_orders_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/work_orders/:id' do
    context 'when user owns the record' do
      it 'returns the work order' do
        get api_v1_work_order_path(work_order), headers: auth_headers(user)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when admin accesses any record' do
      it 'returns the work order' do
        get api_v1_work_order_path(work_order), headers: auth_headers(admin_user)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user does not own the record' do
      let(:other_user) { create(:user) }

      it 'returns forbidden' do
        get api_v1_work_order_path(work_order), headers: auth_headers(other_user)
        expect(response).to have_http_status(:forbidden), response.body
      end
    end
  end

  describe 'POST /api/v1/work_orders' do
    let(:valid_params) do
      {
        work_order: {
          name: 'Test WRS',
          building_id: building.id,
          flat_number: 'Apt 1'
        }
      }
    end

    context 'when user is authenticated' do
      it 'creates a new work order' do
        expect do
          post api_v1_work_orders_path, params: valid_params.to_json, headers: auth_headers(user)
        end.to change(WorkOrder, :count).by(1)
      end

      it 'returns created status' do
        post api_v1_work_orders_path, params: valid_params.to_json, headers: auth_headers(user)
        expect(response).to have_http_status(:created)
      end

      it 'returns the created work order data' do
        post api_v1_work_orders_path, params: valid_params.to_json, headers: auth_headers(user)
        expect(response.body).to include('Test WRS')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          work_order: {
            name: '', # Invalid: empty name
            building_id: building.id
          }
        }
      end

      it 'does not create a work order' do
        expect do
          post api_v1_work_orders_path, params: invalid_params.to_json, headers: auth_headers(user)
        end.not_to change(WorkOrder, :count)
      end

      it 'returns unprocessable entity' do
        post api_v1_work_orders_path, params: invalid_params.to_json, headers: auth_headers(user)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/work_orders/:id' do
    let(:update_params) do
      {
        work_order: {
          name: 'Updated WRS'
        }
      }
    end

    context 'when user owns the record' do
      it 'updates the work order' do
        patch api_v1_work_order_path(work_order), params: update_params.to_json,
                                                  headers: auth_headers(user)
        work_order.reload
        expect(work_order.name).to eq('Updated WRS')
      end

      it 'returns success status' do
        patch api_v1_work_order_path(work_order), params: update_params.to_json,
                                                  headers: auth_headers(user)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'DELETE /api/v1/work_orders/:id' do
    context 'when user owns the record' do
      it 'soft deletes the work order' do
        expect do
          delete api_v1_work_order_path(work_order), headers: auth_headers(user)
        end.to change { work_order.reload.deleted_at }.from(nil)
      end

      it 'returns success status' do
        delete api_v1_work_order_path(work_order), headers: auth_headers(user)
        expect(response).to have_http_status(:success)
      end
    end
  end
end
