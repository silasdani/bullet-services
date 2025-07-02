# frozen_string_literal: true

class Api::V1::UsersController < Api::V1::BaseController
  before_action :set_user, only: [:show, :update, :destroy]

  def index
    authorize User
    @users = User.includes([image_attachment: :blob]).order(created_at: :desc)
    render json: users_json(@users)
  end

  def show
    authorize @user
    render json: user_json(@user)
  end

  def create
    @user = User.new(user_params)
    authorize @user
    if @user.save
      attach_image if params[:image].present?
      render json: user_json(@user), status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @user
    if @user.update(user_params)
      attach_image if params[:image].present?
      render json: user_json(@user)
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
    render json: user_json(current_user)
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def user_params
    params.require(:user).permit(:email, :name, :nickname, :role, :password, :password_confirmation)
  end

  def attach_image
    @user.image.attach(params[:image])
  end

  def users_json(users)
    users.map { |u| user_json(u) }
  end

  def user_json(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      nickname: user.nickname,
      role: user.role,
      created_at: user.created_at,
      updated_at: user.updated_at,
      image: user.image.attached? ? {
        id: user.image.id,
        url: url_for(user.image),
        filename: user.image.filename
      } : nil
    }
  end
end