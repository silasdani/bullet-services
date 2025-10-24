# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::WindowScheduleRepairsController, type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:window_schedule_repair) { create(:window_schedule_repair, user: user) }

  # Helper method for API authentication using Devise Token Auth
  def auth_headers(user)
    # Create a token if none exists
    if user.tokens.empty?
      user.create_token
      user.save!
    end

    token_data = user.tokens.values.first
    client_id = user.tokens.keys.first

    {
      'access-token' => token_data['token'],
      'client' => client_id,
      'uid' => user.uid,
      'Content-Type' => 'application/json'
    }
  end

  describe 'GET /api/v1/window_schedule_repairs' do
    context 'when user is authenticated' do
      it 'returns a successful response' do
        get api_v1_window_schedule_repairs_path, headers: auth_headers(user)
        expect(response).to have_http_status(:success)
      end

      it 'returns window schedule repairs data' do
        window_schedule_repair # Create the record
        get api_v1_window_schedule_repairs_path, headers: auth_headers(user)
        expect(response.body).to include('data')
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get api_v1_window_schedule_repairs_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/window_schedule_repairs/:id' do
    context 'when user owns the record' do
      it 'returns the window schedule repair' do
        get api_v1_window_schedule_repair_path(window_schedule_repair), headers: auth_headers(user)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when admin accesses any record' do
      it 'returns the window schedule repair' do
        get api_v1_window_schedule_repair_path(window_schedule_repair), headers: auth_headers(admin_user)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user does not own the record' do
      let(:other_user) { create(:user) }

      it 'returns forbidden' do
        get api_v1_window_schedule_repair_path(window_schedule_repair), headers: auth_headers(other_user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/window_schedule_repairs' do
    let(:valid_params) do
      {
        window_schedule_repair: {
          name: 'Test WRS',
          address: '123 Test St',
          flat_number: 'Apt 1'
        }
      }
    end

    context 'when user is authenticated' do
      it 'creates a new window schedule repair' do
        expect do
          post api_v1_window_schedule_repairs_path, params: valid_params, headers: auth_headers(user)
        end.to change(WindowScheduleRepair, :count).by(1)
      end

      it 'returns created status' do
        post api_v1_window_schedule_repairs_path, params: valid_params, headers: auth_headers(user)
        expect(response).to have_http_status(:created)
      end

      it 'returns the created window schedule repair data' do
        post api_v1_window_schedule_repairs_path, params: valid_params, headers: auth_headers(user)
        expect(response.body).to include('Test WRS')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          window_schedule_repair: {
            name: '', # Invalid: empty name
            address: '123 Test St'
          }
        }
      end

      it 'does not create a window schedule repair' do
        expect do
          post api_v1_window_schedule_repairs_path, params: invalid_params, headers: auth_headers(user)
        end.not_to change(WindowScheduleRepair, :count)
      end

      it 'returns unprocessable entity' do
        post api_v1_window_schedule_repairs_path, params: invalid_params, headers: auth_headers(user)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /api/v1/window_schedule_repairs/:id' do
    let(:update_params) do
      {
        window_schedule_repair: {
          name: 'Updated WRS'
        }
      }
    end

    context 'when user owns the record' do
      it 'updates the window schedule repair' do
        patch api_v1_window_schedule_repair_path(window_schedule_repair), params: update_params,
                                                                          headers: auth_headers(user)
        window_schedule_repair.reload
        expect(window_schedule_repair.name).to eq('Updated WRS')
      end

      it 'returns success status' do
        patch api_v1_window_schedule_repair_path(window_schedule_repair), params: update_params,
                                                                          headers: auth_headers(user)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'DELETE /api/v1/window_schedule_repairs/:id' do
    context 'when user owns the record' do
      it 'soft deletes the window schedule repair' do
        expect do
          delete api_v1_window_schedule_repair_path(window_schedule_repair), headers: auth_headers(user)
        end.to change { window_schedule_repair.reload.deleted_at }.from(nil)
      end

      it 'returns success status' do
        delete api_v1_window_schedule_repair_path(window_schedule_repair), headers: auth_headers(user)
        expect(response).to have_http_status(:success)
      end
    end
  end
end
