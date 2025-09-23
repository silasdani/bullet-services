# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < DeviseTokenAuth::RegistrationsController
  before_action :configure_permitted_parameters

  # Disable account deletion via /auth
  def destroy
    head :method_not_allowed
  end

  def render_create_success
    render json: {
      status: "success",
      data: UserSerializer.new(@resource).as_json
    }, status: :ok
  end

  def render_create_error
    render json: {
      status: "error",
      errors: @resource&.errors&.full_messages
    }, status: :unprocessable_entity
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:nickname, :name])
  end
end
