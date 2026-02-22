# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Freshbooks::ConnectionCheckService do
  describe '.check' do
    context 'when no token is configured' do
      before { allow(FreshbooksToken).to receive(:current).and_return(nil) }

      it 'returns ok: false with error message' do
        result = described_class.check

        expect(result).to eq(ok: false, error: 'No token configured')
      end
    end

    context 'when token exists and API responds successfully' do
      let(:token) { instance_double(FreshbooksToken, access_token: 'valid-token') }

      before do
        allow(FreshbooksToken).to receive(:current).and_return(token)
        allow(HTTParty).to receive(:get).and_return(
          instance_double(HTTParty::Response, success?: true)
        )
      end

      it 'returns ok: true' do
        result = described_class.check

        expect(result).to eq(ok: true)
      end

      it 'calls the FreshBooks users/me endpoint' do
        described_class.check

        expect(HTTParty).to have_received(:get).with(
          'https://api.freshbooks.com/auth/api/v1/users/me',
          hash_including(
            headers: hash_including(
              'Authorization' => 'Bearer valid-token',
              'Api-Version' => 'alpha'
            )
          )
        )
      end
    end

    context 'when API returns an error' do
      let(:token) { instance_double(FreshbooksToken, access_token: 'bad-token') }

      before do
        allow(FreshbooksToken).to receive(:current).and_return(token)
        allow(HTTParty).to receive(:get).and_return(
          instance_double(
            HTTParty::Response,
            success?: false,
            code: 401,
            body: '{"error":"invalid_token"}'
          )
        )
      end

      it 'returns ok: false with error message' do
        result = described_class.check

        expect(result[:ok]).to be false
        expect(result[:error]).to include('invalid_token')
      end
    end
  end
end
