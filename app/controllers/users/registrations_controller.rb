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

    def create
      super do |resource|
        # Set role based on email domain if role wasn't explicitly set
        # Check if email suggests contractor role
        if resource.persisted? && ['client',
                                   0].include?(resource.role) && resource.email&.match?(/contractor|employee|@bullet\./)
          resource.update_column(:role, :contractor)
          resource.reload
        end
      end
    end

    private

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[nickname name role])
    end

    def formatted_errors
      return {} unless @resource&.errors

      @resource.errors.messages.transform_values { |messages| messages.map(&:to_s) }
    end
  end
end
