# frozen_string_literal: true

module Users
  class ConfirmationsController < Devise::ConfirmationsController
    layout 'admin'
  end
end
