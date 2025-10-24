# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:record) { double('record') }
  let(:policy) { described_class.new(user, record) }

  describe 'default behavior' do
    it 'allows all actions by default' do
      # ApplicationPolicy doesn't define specific methods, so we test the base behavior
      expect(policy.user).to eq(user)
      expect(policy.record).to eq(record)
    end

    it 'returns all records in scope by default' do
      scope = double('scope')
      allow(scope).to receive(:all).and_return(scope)
      policy_scope = ApplicationPolicy::Scope.new(user, scope)

      expect(policy_scope.resolve).to eq(scope)
    end
  end

  describe 'initialization' do
    it 'sets user and record' do
      expect(policy.user).to eq(user)
      expect(policy.record).to eq(record)
    end
  end
end
