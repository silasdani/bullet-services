class ImagePolicy < ApplicationPolicy
  def upload_window_image?
    # Users can upload images to windows they own or are assigned to
    user.is_admin? ||
    user.is_employee? ||
    (user.client? && record.window_schedule_repair.user == user)
  end

  def upload_multiple_images?
    # Users can upload multiple images to WRS they own or are assigned to
    user.is_admin? ||
    user.is_employee? ||
    (user.client? && record.user == user)
  end
end
