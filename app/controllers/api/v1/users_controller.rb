# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::V1::BaseController
      before_action :set_user, only: %i[show update destroy]

      def index
        authorize User
        @users = User.includes([image_attachment: :blob]).order(created_at: :desc)
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

      def me
        Rails.logger.info "Current user: #{current_user.inspect}"
        Rails.logger.info "User authenticated: #{user_signed_in?}"

        if current_user
          render json: current_user
        else
          render json: { error: 'Not authenticated' }, status: :unauthorized
        end
      end

      private

      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def user_params
        if params[:user].present?
          permitted = params.require(:user).permit(:email, :name, :nickname, :password, :password_confirmation)
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
