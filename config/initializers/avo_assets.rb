# frozen_string_literal: true

# Fix for Avo 3.29 nil stylesheet_assets_path error with Rails 8
# Avo's StylesheetComponent should set @stylesheet_assets_path, but it's nil
# This ensures it's set before the layout tries to use it
module Avo
  module ApplicationControllerPatch
    def self.included(base)
      base.class_eval do
        before_action :ensure_avo_stylesheet_path, prepend: true

        private

        def ensure_avo_stylesheet_path
          # Only set if not already set by Avo's component
          return if defined?(@stylesheet_assets_path) && @stylesheet_assets_path.present?

          # Try to get it from Avo's asset manager
          begin
            asset_manager = Avo.asset_manager
            if asset_manager.respond_to?(:stylesheet_path)
              # Pass the request context if needed
              @stylesheet_assets_path = asset_manager.stylesheet_path(request) rescue asset_manager.stylesheet_path
            end
          rescue StandardError => e
            Rails.logger.warn "Avo asset manager error: #{e.message}"
          end

          # Fallback: use Avo's default stylesheet (empty string means skip the tag)
          @stylesheet_assets_path ||= ""
        end
      end
    end
  end
end

# Apply patch after Avo is loaded
Rails.application.config.after_initialize do
  if defined?(Avo::BaseController)
    Avo::BaseController.include(Avo::ApplicationControllerPatch)
  end
end
