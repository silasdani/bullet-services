# frozen_string_literal: true

class NavigationComponent < ApplicationComponent
  def initialize(current_path:)
    super
    @current_path = current_path
  end

  private

  attr_reader :current_path

  def active_class(path)
    current_path == path ? 'font-semibold' : ''
  end
end
