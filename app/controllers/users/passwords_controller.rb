# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    layout 'admin'
  end
end
