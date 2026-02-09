# frozen_string_literal: true

module AvoAdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_admin_access, if: -> { defined?(Avo) && self.class < Avo::BaseController }
  end

  private

  def ensure_admin_access
    return if current_user&.is_admin?

    redirect_to main_app.root_path, alert: 'You are not authorized to access this page.'
  end
end
