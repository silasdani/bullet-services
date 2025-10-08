# frozen_string_literal: true

RailsAdmin.config do |config|
  # Explicitly set asset_source for RailsAdmin 3.x to silence warnings
  config.asset_source = :sprockets
  # Authenticate: ensure user is logged in via Devise session
  config.authenticate_with do
    redirect_to main_app.new_user_session_path unless request.env["warden"]&.user(:user).present?
  end

  # Authorize: only admins/superadmins allowed
  config.authorize_with do
    redirect_to main_app.root_path, alert: "You are not authorized to access this page." unless current_user&.is_admin?
  end

  config.current_user_method(&:current_user)

  config.authorize_with do
    unless current_user&.is_admin?
      redirect_to main_app.root_path, alert: "You are not authorized to access this page."
    end
  end

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app
  end
end
