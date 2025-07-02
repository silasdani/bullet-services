# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < DeviseTokenAuth::RegistrationsController
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
end
