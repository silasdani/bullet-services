# frozen_string_literal: true

class WebsiteController < ApplicationController
  # Public website pages - skip authorization
  skip_before_action :verify_authenticity_token, only: [:contact_submit]

  def home
    # Homepage
  end

  def about
    # About page
  end

  def contact_submit
    service = Website::ContactFormService.new(contact_params)
    result = service.call

    if result.success?
      redirect_to root_path, notice: 'Thank you! Your submission has been received!'
    else
      redirect_to root_path(anchor: 'contact'),
                  alert: 'Oops! Something went wrong while submitting the form. Please refresh and try again.'
    end
  end

  private

  def contact_params
    params.permit(:name, :email, :message)
  end
end
