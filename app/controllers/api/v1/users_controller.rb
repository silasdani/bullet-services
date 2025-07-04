# frozen_string_literal: true

class Api::V1::UsersController < Api::V1::BaseController
  before_action :set_user, only: [:show, :update, :destroy]

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
    @user.destroy
    head :no_content
  end

  def me
    authorize current_user, :me?
    render json: current_user
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def user_params
    params.require(:user).permit(:email, :name, :nickname, :role, :password, :password_confirmation, :image)
  end

  def attach_image
    @user.image.attach(params[:image])
  end
end