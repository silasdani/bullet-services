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
      # Create the WRS first (this will generate the slug)
      @wrs = @user.window_schedule_repairs.build(
        name: @params[:name],
        address: @params[:address],
        flat_number: @params[:flat_number],
        details: @params[:details]
      )

      # Save the WRS first to generate slug and pass validations
      unless @wrs.save
        @errors = @wrs.errors.full_messages
        return { success: false, errors: @errors }
      end

      # Create windows with their tools (this will save them individually)
      create_windows_and_tools

      # Calculate totals after windows and tools are created
      @wrs.calculate_totals

      # Save the WRS again with the calculated totals
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
      @wrs.assign_attributes(
        name: @params[:name],
        address: @params[:address],
        flat_number: @params[:flat_number],
        details: @params[:details],
        is_draft: true,
      )

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

  def create_windows_and_tools
    return unless @params[:windows_attributes]

    windows_attrs = @params[:windows_attributes].to_h

    windows_attrs.values.each_with_index do |window_attrs, index|
      next if window_attrs[:location].blank?

      window = @wrs.windows.build(
        location: window_attrs[:location]
      )

      # Skip image validation during creation
      window.skip_image_validation = true

      # Create tools for this window
      if window_attrs[:tools_attributes]
        tools_attrs = window_attrs[:tools_attributes].to_h
        tools_attrs.values.each do |tool_attrs|
          next if tool_attrs[:name].blank?

          tool = window.tools.build(
            name: tool_attrs[:name],
            price: tool_attrs[:price] || 0
          )
        end
      end

      # Save the window first (without image)
      unless window.save
        raise "Failed to save window #{index}: #{window.errors.full_messages}"
      end

      # Now attach the image to the saved window
      if window_attrs[:image].present? && window_attrs[:image].respond_to?(:content_type)
        begin
          # Simply attach the uploaded file directly - ActiveStorage handles the rest
          window.image.attach(window_attrs[:image])

          # Verify the image is present
          if window.image.present?
            # Re-enable image validation for future operations
            window.skip_image_validation = false
          else
            Rails.logger.error "Image upload failed for window #{index}"
          end
        rescue => e
          Rails.logger.error "Error attaching image to window #{index}: #{e.message}"
          Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join("\n")}"
          # Re-enable image validation even if upload failed
          window.skip_image_validation = false
        end
      else
        # Re-enable image validation even if no image was provided
        window.skip_image_validation = false
      end
    end
  end

  def update_windows_and_tools
    return unless @params[:windows_attributes]

    windows_attrs = @params[:windows_attributes].to_h

    windows_attrs.values.each do |window_attrs|
      next if window_attrs[:location].blank?

      if window_attrs[:id].present?
        # Update existing window
        window = @wrs.windows.find(window_attrs[:id])
        window.assign_attributes(location: window_attrs[:location])

        # Update tools
        update_window_tools(window, window_attrs[:tools_attributes])

        # Save the updated window
        unless window.save
          raise "Failed to save updated window: #{window.errors.full_messages}"
        end

        # Handle image if provided
        if window_attrs[:image].present? && window_attrs[:image].respond_to?(:content_type)
          # This is a file upload, replace the existing image
          window.image.attach(window_attrs[:image])
        end
      else
        # Create new window
        window = @wrs.windows.build(location: window_attrs[:location])

        # Skip image validation during creation
        window.skip_image_validation = true

        create_window_tools(window, window_attrs[:tools_attributes])

        # Save the new window first
        unless window.save
          raise "Failed to save new window: #{window.errors.full_messages}"
        end

        # Now handle the image for the saved window
        if window_attrs[:image].present? && window_attrs[:image].respond_to?(:content_type)
          # Attach the uploaded file
          window.image.attach(window_attrs[:image])
          # Re-enable image validation
          window.skip_image_validation = false
        else
          # Re-enable image validation even if no image was provided
          window.skip_image_validation = false
        end
      end
    end
  end

  def create_window_tools(window, tools_attrs)
    return unless tools_attrs

    tools_attrs = tools_attrs.to_h if tools_attrs.respond_to?(:to_h)

    tools_attrs.values.each do |tool_attrs|
      next if tool_attrs[:name].blank?

      window.tools.build(
        name: tool_attrs[:name],
        price: tool_attrs[:price] || 0
      )
    end
  end

  def update_window_tools(window, tools_attrs)
    return unless tools_attrs

    tools_attrs = tools_attrs.to_h if tools_attrs.respond_to?(:to_h)

    # Clear existing tools
    window.tools.destroy_all

    # Create new tools
    tools_attrs.values.each do |tool_attrs|
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

  def sync_from_webflow
    WebflowDownloadJob.perform_later(@wrs.id)
  end
end
