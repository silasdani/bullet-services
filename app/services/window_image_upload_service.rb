class WindowImageUploadService
  attr_reader :window, :errors

  def initialize(window)
    @window = window
    @errors = []
  end

  def upload_image(image_file)
    return { success: false, errors: ['No image provided'] } unless image_file.present?

    begin
      # Remove existing image
      @window.image.purge if @window.image.attached?

      # Attach new image
      @window.image.attach(image_file)

      # Generate proper filename
      filename = generate_image_filename
      @window.image.blob.update(filename: filename)

      # Sync to Webflow if needed
      sync_to_webflow if should_sync_to_webflow?

      {
        success: true,
        image_url: @window.image_url,
        image_name: filename,
        message: 'Image uploaded successfully'
      }
    rescue => e
      @errors << "Failed to upload image: #{e.message}"
      { success: false, errors: @errors }
    end
  end

  private

  def generate_image_filename
    window_number = get_window_number
    extension = @window.image.blob.filename.extension
    "window-#{window_number}-image.#{extension}"
  end

  def get_window_number
    # Get the position of this window within the WRS (1-based)
    @window.window_schedule_repair.windows.order(:created_at).index(@window) + 1
  end

  def should_sync_to_webflow?
    @window.window_schedule_repair.webflow_collection_id.present?
  end

  def sync_to_webflow
    WebflowUploadJob.perform_later(@window.window_schedule_repair.id)
  end
end
