# frozen_string_literal: true

module Buildings
  class UpdateScheduleOfConditionService
    def initialize(building:, params:)
      @building = building
      @params = params || {}
    end

    def call
      assign_schedule_of_condition_notes
      handle_schedule_of_condition_images
      save_schedule_of_condition
    end

    private

    attr_reader :building, :params

    def assign_schedule_of_condition_notes
      return unless params.key?(:schedule_of_condition_notes)

      building.schedule_of_condition_notes = params[:schedule_of_condition_notes]
    end

    def handle_schedule_of_condition_images
      return purge_all_schedule_of_condition_images if purge_all_images?

      purge_specific_schedule_of_condition_images
      attach_new_schedule_of_condition_images
    end

    def purge_all_schedule_of_condition_images
      return unless building.schedule_of_condition_images.attached?

      building.schedule_of_condition_images.purge
    end

    def purge_all_images?
      ['true', true].include?(params[:purge_all_images])
    end

    def purge_specific_schedule_of_condition_images
      return unless params[:purge_image_ids].present?

      purge_specific_images(params[:purge_image_ids])
    end

    def attach_new_schedule_of_condition_images
      images = params[:schedule_of_condition_images]
      return unless images.present?

      images.each do |image|
        next if image.nil?
        next if image.is_a?(String) && image.empty?

        building.schedule_of_condition_images.attach(image)
      end
    end

    def purge_specific_images(image_ids)
      return unless building.schedule_of_condition_images.attached?

      ids_to_purge = Array(image_ids).map(&:to_i).compact
      return if ids_to_purge.empty?

      attachments_to_purge = building.schedule_of_condition_images_attachments.where(id: ids_to_purge)
      attachments_to_purge.each(&:purge)
    end

    def save_schedule_of_condition
      return false unless building.save

      building.schedule_of_condition_images.reload if building.schedule_of_condition_images.attached?
      true
    end
  end
end
