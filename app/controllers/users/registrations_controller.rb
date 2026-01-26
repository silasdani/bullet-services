# frozen_string_literal: true

module Users
  class RegistrationsController < DeviseTokenAuth::RegistrationsController
    before_action :configure_permitted_parameters

    def destroy
      head :method_not_allowed
    end

    def render_create_success
      render json: {
        status: 'success',
        data: UserSerializer.new(@resource).as_json
      }, status: :ok
    end

    def render_create_error
      render json: {
        status: 'error',
        errors: formatted_errors
      }, status: :unprocessable_content
    end

    private

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[nickname name])
    end

    def formatted_errors
      return {} unless @resource&.errors

      @resource.errors.messages.transform_values { |messages| messages.map(&:to_s) }
    end
  end
end
