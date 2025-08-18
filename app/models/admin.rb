# frozen_string_literal: true

class Admin < User
  # on super.role = admin
  def role
    'admin'
  end

  rails_admin do
    object_label_method do
      :email
    end
  end

  def set_confirmed
    self.confirmed_at = Time.current
  end

  def set_default_role
    self.role ||= :admin
  end

  after_initialize :set_default_role, if: :new_record?
  after_create :set_confirmed
end
