# frozen_string_literal: true

# Add admin authorization to Avo controllers
Rails.application.config.after_initialize do
  if defined?(Avo::BaseController)
    Avo::BaseController.include(AvoAdminAuthorization)
  end
end
