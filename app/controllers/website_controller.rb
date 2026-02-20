# frozen_string_literal: true

class WebsiteController < ApplicationController
  # Public website pages - skip authorization
  protect_from_forgery with: :exception, except: %i[contact_submit wrs_decision]

  before_action :verify_contact_form_request, only: [:contact_submit]
  before_action :verify_wrs_decision_request, only: [:wrs_decision]

  def home
    # Homepage
  end

  def about
    # About page
  end

  def services
    # Services page
  end

  def terms
    # Site-wide Terms and Conditions (footer, general use)
  end

  def wrs_terms
    # WRS-specific contract terms (accept/decline repairs)
  end

  def wrs_show
    load_wrs
    return unless @wrs

    @decision_form = WorkOrderDecisionForm.new
  end

  def wrs_decision
    load_wrs
    return unless @wrs

    # Prevent duplicate submissions if invoice already exists
    if @wrs.invoices.exists?
      redirect_to wrs_show_path(slug: @wrs.slug),
                  alert: 'A decision has already been made for this work order. Invoice already exists.'
      return
    end

    @decision_form = WorkOrderDecisionForm.new(wrs_decision_params)

    return render_invalid_wrs_decision unless @decision_form.valid?

    result = process_wrs_decision
    handle_wrs_decision_result(result)
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
    # Find work order by slug — must be published (not draft, not archived) and not soft-deleted
    @wrs = WorkOrder.active.published.includes(windows: :tools, invoices: []).find_by(slug: params[:slug])

    return if @wrs

    redirect_to root_path, alert: 'Work order not found.'
  end

  def contact_params
    params.permit(:name, :email, :message)
  end

  def wrs_decision_params
    params.require(:work_order_decision_form).permit(:first_name, :last_name, :email, :decision, :accept_terms)
  end

  def process_wrs_decision
    WorkOrders::DecisionService.new(
      work_order: @wrs,
      first_name: @decision_form.first_name,
      last_name: @decision_form.last_name,
      email: @decision_form.email,
      decision: @decision_form.decision
    ).call
  end

  def render_invalid_wrs_decision
    flash.now[:alert] = 'Please correct the errors below.'
    render :wrs_show, status: :unprocessable_content
  end

  def handle_wrs_decision_result(result)
    if result.success?
      return redirect_to wrs_show_path(slug: @wrs.slug),
                         notice: 'Thank you, your decision has been recorded.'
    end

    flash.now[:alert] = 'Something went wrong while processing your decision. Please try again.'
    render :wrs_show, status: :unprocessable_content
  end

  def verify_contact_form_request
    return if request.get? || request.head?

    return if verified_request?

    Rails.logger.warn "CSRF verification failed for contact form from #{request.remote_ip}"
    redirect_to root_path(anchor: 'contact'),
                alert: 'Security verification failed. Please try again.',
                status: :forbidden
  end

  def verify_wrs_decision_request
    return if request.get? || request.head?

    unless params[:work_order_decision_form].present?
      Rails.logger.warn "WRS decision request missing form parameters from #{request.remote_ip}"
      redirect_to wrs_show_path(slug: params[:slug]),
                  alert: 'Invalid request. Please try again.',
                  status: :bad_request
      return
    end

    nil if verified_request?
  end
end
