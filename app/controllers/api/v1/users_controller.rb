# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::V1::BaseController
      before_action :set_user, only: %i[show update destroy]

      def index
        authorize User
        @users = User.includes(image_attachment: :blob).order(created_at: :desc)
        render json: @users
      end

      def show
        authorize @user
        render json: @user
      end

      def create
        @user = User.new(user_params)
        authorize @user
        if @user.save
          attach_image if params[:image].present?
          render json: @user, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @user
        if @user.update(user_params)
          attach_image if params[:image].present?
          render json: @user
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @user
        @user.soft_delete!
        head :no_content
      end

      # POST /api/v1/users/:id/block
      def block
        @user = User.find(params[:id])
        authorize @user, :block?

        @user.block!
        render json: { message: 'User blocked successfully', user: @user }, status: :ok
      end

      # POST /api/v1/users/:id/unblock
      def unblock
        @user = User.find(params[:id])
        authorize @user, :unblock?

        @user.unblock!
        render json: { message: 'User unblocked successfully', user: @user }, status: :ok
      end

      def me
        Rails.logger.info "Current user: #{current_user.inspect}"
        Rails.logger.info "User authenticated: #{user_signed_in?}"

        if current_user
          render json: current_user
        else
          render json: { error: 'Not authenticated' }, status: :unauthorized
        end
      end

      # POST /api/v1/users/register_fcm_token
      def register_fcm_token
        authorize User, :update?

        fcm_token = params[:fcm_token]

        unless fcm_token.present?
          return render_error(
            message: 'FCM token is required',
            status: :unprocessable_entity
          )
        end

        if current_user.update(fcm_token: fcm_token)
          render_success(
            data: { fcm_token_registered: true },
            message: 'FCM token registered successfully'
          )
        else
          render_error(
            message: 'Failed to register FCM token',
            details: current_user.errors.full_messages
          )
        end
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        if params[:user].present?
          permitted = params.require(:user).permit(:email, :name, :nickname, :password, :password_confirmation,
                                                   :fcm_token)
          # Only allow admins to update role
          permitted[:role] = params[:user][:role] if current_user&.admin? && params[:user][:role].present?
          permitted
        else
          {}
        end
      end

      def attach_image
        @user.image.attach(params[:image])
      end
    end
  end
end
