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

  def wrs_show
    load_wrs
    return unless @wrs

    @decision_form = WrsDecisionForm.new
  end

  def wrs_decision
    load_wrs
    return unless @wrs

    @decision_form = WrsDecisionForm.new(wrs_decision_params)

    if @decision_form.valid?
      # Actual processing (FreshBooks, emails, etc.) is handled by Wrs::DecisionService
      service = Wrs::DecisionService.new(
        window_schedule_repair: @wrs,
        first_name: @decision_form.first_name,
        last_name: @decision_form.last_name,
        email: @decision_form.email,
        decision: @decision_form.decision
      )

      result = service.call

      if result.success?
        redirect_to wrs_show_path(slug: @wrs.slug), notice: 'Thank you, your decision has been recorded.'
      else
        flash.now[:alert] = 'Something went wrong while processing your decision. Please try again.'
        render :wrs_show, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = 'Please correct the errors below.'
      render :wrs_show, status: :unprocessable_entity
    end
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

  def load_wrs
    # Find WRS by slug, excluding soft-deleted records
    @wrs = WindowScheduleRepair.active.includes(windows: :tools).find_by(slug: params[:slug])

    return if @wrs

    redirect_to root_path, alert: 'Window Schedule Repair not found.'
  end

  def contact_params
    params.permit(:name, :email, :message)
  end

  def wrs_decision_params
    params.require(:wrs_decision_form).permit(:first_name, :last_name, :email, :decision, :accept_terms)
  end
end
