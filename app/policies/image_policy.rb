# frozen_string_literal: true

class ImagePolicy < ApplicationPolicy
  def upload_window_image?
    # Users can upload images to windows they own or are assigned to
    user.is_admin? ||
      user.is_employee? ||
      (user.client? && record.work_order.user == user)
  end

  def upload_multiple_images?
    # Users can upload multiple images to work orders they own or are assigned to
    user.is_admin? ||
      user.is_employee? ||
      (user.client? && record.user == user)
  end
end
