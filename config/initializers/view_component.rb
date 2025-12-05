# frozen_string_literal: true

# ViewComponent configuration
# Learn more: https://viewcomponent.org/guide/getting-started.html

Rails.application.config.view_component.preview_paths << Rails.root.join("spec/components/previews")
Rails.application.config.view_component.show_previews = Rails.env.development?
