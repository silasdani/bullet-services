# frozen_string_literal: true

class Api::V1::UsersController < Api::V1::BaseController
  before_action :set_user, only: [:show, :update, :destroy]

  def index
    authorize User
    @users = User.includes([avatar_attachment: :blob]).order(created_at: :desc)
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
      attach_avatar if params[:avatar].present?
      render json: user_json(@user), status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @user
    if @user.update(user_params)
      attach_avatar if params[:avatar].present?
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

  def attach_avatar
    @user.avatar.attach(params[:avatar])
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
      avatar: user.avatar.attached? ? {
        id: user.avatar.id,
        url: url_for(user.avatar),
        filename: user.avatar.filename
      } : nil
    }
  end
end