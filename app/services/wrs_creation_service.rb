class WrsCreationService
  attr_reader :wrs, :errors

  def initialize(user, params)
    @user = user
    @params = params
    @errors = []
    @wrs = nil
  end

  def create
    ActiveRecord::Base.transaction do
      # Create the WRS
      @wrs = @user.window_schedule_repairs.build(wrs_params)

      # Create windows with their tools
      create_windows_and_tools

      # Calculate totals
      @wrs.calculate_totals

      # Save everything
      if @wrs.save
        # Sync to Webflow if collection ID is provided
        sync_to_webflow if @wrs.webflow_collection_id.present?

        { success: true, wrs: @wrs }
      else
        @errors = @wrs.errors.full_messages
        { success: false, errors: @errors }
      end
    rescue => e
      @errors << "Failed to create WRS: #{e.message}"
      { success: false, errors: @errors }
    end
  end

  def update(wrs_id)
    @wrs = @user.window_schedule_repairs.find(wrs_id)

    ActiveRecord::Base.transaction do
      # Update WRS basic info
      @wrs.assign_attributes(wrs_params)

      # Update windows and tools
      update_windows_and_tools

      # Recalculate totals
      @wrs.calculate_totals

      if @wrs.save
        # Sync to Webflow
        sync_to_webflow if @wrs.webflow_collection_id.present?

        { success: true, wrs: @wrs }
      else
        @errors = @wrs.errors.full_messages
        { success: false, errors: @errors }
      end
    rescue => e
      @errors << "Failed to update WRS: #{e.message}"
      { success: false, errors: @errors }
    end
  end

  private

  def wrs_params
    @params.permit(
      :name, :slug, :webflow_collection_id, :webflow_item_id, :reference_number,
      :address, :flat_number, :details, :status, :status_color
    )
  end

  def create_windows_and_tools
    return unless @params[:windows_attributes]

    @params[:windows_attributes].each do |window_attrs|
      next if window_attrs[:location].blank?

      window = @wrs.windows.build(
        location: window_attrs[:location]
      )

      # Create tools for this window
      if window_attrs[:tools_attributes]
        window_attrs[:tools_attributes].each do |tool_attrs|
          next if tool_attrs[:name].blank?

          window.tools.build(
            name: tool_attrs[:name],
            price: tool_attrs[:price] || 0
          )
        end
      end
    end
  end

  def update_windows_and_tools
    return unless @params[:windows_attributes]

    @params[:windows_attributes].each do |window_attrs|
      next if window_attrs[:location].blank?

      if window_attrs[:id].present?
        # Update existing window
        window = @wrs.windows.find(window_attrs[:id])
        window.assign_attributes(location: window_attrs[:location])

        # Update tools
        update_window_tools(window, window_attrs[:tools_attributes])
      else
        # Create new window
        window = @wrs.windows.build(location: window_attrs[:location])
        create_window_tools(window, window_attrs[:tools_attributes])
      end
    end
  end

  def create_window_tools(window, tools_attrs)
    return unless tools_attrs

    tools_attrs.each do |tool_attrs|
      next if tool_attrs[:name].blank?

      window.tools.build(
        name: tool_attrs[:name],
        price: tool_attrs[:price] || 0
      )
    end
  end

  def update_window_tools(window, tools_attrs)
    return unless tools_attrs

    # Clear existing tools
    window.tools.destroy_all

    # Create new tools
    tools_attrs.each do |tool_attrs|
      next if tool_attrs[:name].blank?

      window.tools.create!(
        name: tool_attrs[:name],
        price: tool_attrs[:price] || 0
      )
    end
  end

  def sync_to_webflow
    WebflowUploadJob.perform_later(@wrs.id)
  end
end
