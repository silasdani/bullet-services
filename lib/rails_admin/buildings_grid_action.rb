# frozen_string_literal: true

module RailsAdmin
  module Config
    module Actions
      class BuildingsGrid < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :action_name do
          :buildings_grid
        end

        register_instance_option :root do
          true
        end

        register_instance_option :visible do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            # Load all buildings with their window_schedule_repairs (eager loading)
            @buildings = Building.includes(:window_schedule_repairs)
                                  .where(deleted_at: nil)
                                  .order(created_at: :desc)

            # Group WRS by building and flat_number for each building
            @buildings_data = @buildings.map do |building|
              # Group WRS by flat_number
              flats_map = {}
              building.window_schedule_repairs.each do |wrs|
                flat_number = wrs.flat_number || 'Unspecified Unit'
                flats_map[flat_number] ||= []
                flats_map[flat_number] << wrs
              end

              # Convert to array and sort flats
              flats = flats_map.map do |flat_number, wrs_items|
                {
                  flat_number: flat_number,
                  wrs_items: wrs_items.sort_by { |wrs| wrs.created_at || Time.at(0) }.reverse
                }
              end

              # Sort flats by flat number (handle numeric sorting)
              flats.sort! do |a, b|
                a_flat = a[:flat_number]
                b_flat = b[:flat_number]

                # Put "Unspecified Unit" at the end
                if a_flat == 'Unspecified Unit' && b_flat != 'Unspecified Unit'
                  next 1
                end
                if b_flat == 'Unspecified Unit' && a_flat != 'Unspecified Unit'
                  next -1
                end

                # Try numeric comparison
                a_num = a_flat.to_i
                b_num = b_flat.to_i
                if a_num > 0 && b_num > 0 && a_flat == a_num.to_s && b_flat == b_num.to_s
                  a_num <=> b_num
                else
                  a_flat <=> b_flat
                end
              end

              {
                building: building,
                flats: flats
              }
            end

            render template: 'rails_admin/buildings/grid'
          end
        end

        register_instance_option :link_icon do
          'fa fa-th'
        end

        register_instance_option :show_in_navigation do
          true
        end

        register_instance_option :navigation_label do
          'Grid Views'
        end

        register_instance_option :breadcrumb_parent do
          [:dashboard]
        end

        register_instance_option :i18n_key do
          :buildings_grid
        end
      end
    end
  end
end
