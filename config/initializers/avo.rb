# For more information regarding these settings check out our docs https://docs.avohq.io
# The values disaplayed here are the default ones. Uncomment and change them to fit your needs.
Avo.configure do |config|
  ## == Routing ==
  config.root_path = '/admin'
  # used only when you have custom `map` configuration in your config.ru
  # config.prefix_path = "/internal"

  # Where should the user be redirected when visiting the `/avo` url
  config.home_path = "/admin/dashboard"

  ## == Licensing ==
  # config.license_key = ENV['AVO_LICENSE_KEY']

  ## == Set the context ==
  config.set_context do
    # Return a context object that gets evaluated within Avo::ApplicationController
    # This is optional and can be used to set global context for Avo
  end

  ## == Authentication ==
  config.current_user_method = :current_user
  config.authenticate_with do
    redirect_to "/users/sign_in" unless request.env["warden"]&.user(:user).present?
  end

  ## == Authorization ==
  config.is_admin_method = :is_admin?
  config.authorization_client = nil
  config.explicit_authorization = true

  ## == Localization ==
  # config.locale = 'en-US'

  ## == Resource options ==
  config.resource_row_controls_config = {
    placement: :right,
    float: false,
    show_on_hover: false
  }.freeze
  # config.model_resource_mapping = {}
  # config.default_view_type = :table
  # config.per_page = 24
  # config.per_page_steps = [12, 24, 48, 72]
  # config.via_per_page = 8
  config.id_links_to_resource = true
  # config.pagination = -> do
  #   {
  #     type: :default,
  #     size: 9, # `[1, 2, 2, 1]` for pagy < 9.0
  #   }
  # end

  ## == Response messages dismiss time ==
  # config.alert_dismiss_time = 5000


  ## == Number of search results to display ==
  # config.search_results_count = 8

  ## == Associations lookup list limit ==
  # config.associations_lookup_list_limit = 1000

  ## == Cache options ==
  ## Provide a lambda to customize the cache store used by Avo.
  ## We compute the cache store by default, this is NOT the default, just an example.
  # config.cache_store = -> {
  #   ActiveSupport::Cache.lookup_store(:solid_cache_store)
  # }
  # config.cache_resources_on_index_view = true

  ## == Turbo options ==
  # config.turbo = -> do
  #   {
  #     instant_click: true
  #   }
  # end

  ## == Logger ==
  # config.logger = -> {
  #   file_logger = ActiveSupport::Logger.new(Rails.root.join("log", "avo.log"))
  #
  #   file_logger.datetime_format = "%Y-%m-%d %H:%M:%S"
  #   file_logger.formatter = proc do |severity, time, progname, msg|
  #     "[Avo] #{time}: #{msg}\n".tap do |i|
  #       puts i
  #     end
  #   end
  #
  #   file_logger
  # }

  ## == Customization ==
  config.click_row_to_view_record = true
  config.app_name = 'Bullet Admin'
  # config.timezone = 'UTC'
  # config.currency = 'USD'
  # config.hide_layout_when_printing = false
  # config.full_width_container = false
  # config.full_width_index_view = false
  # config.search_debounce = 300
  # config.view_component_path = "app/components"
  # config.display_license_request_timeout_error = true
  # config.disabled_features = []
  # config.buttons_on_form_footers = true
  # config.field_wrapper_layout = true
  # config.resource_parent_controller = "Avo::ResourcesController"
  # config.first_sorting_option = :desc # :desc or :asc
  # config.exclude_from_status = []
  # config.model_generator_hook = true

  ## == Branding ==
  # Logo is overridden via app/views/avo/partials/_logo.html.erb (shows "Bullet Admin")
  config.branding = {
    colors: {
      background: "#fefefe",  # Light mode background
      50 => "#f8fafc",
      100 => "#f1f5f9",
      200 => "#e2e8f0",
      300 => "#cbd5e1",
      400 => "#94a3b8",
      500 => "#64748b",
      600 => "#475569",
      700 => "#334155",
      800 => "#1e293b",
      900 => "#0f172a",
      950 => "#020617",
    },
    chart_colors: [
      "#3B82F6", # Blue
      "#10B981", # Green
      "#F59E0B", # Amber
      "#EF4444", # Red
      "#8B5CF6", # Purple
      "#EC4899", # Pink
      "#06B6D4", # Cyan
      "#F97316"  # Orange
    ]
  }

  ## == Breadcrumbs ==
  # config.display_breadcrumbs = true
  # config.set_initial_breadcrumbs do
  #   add_breadcrumb "Home", '/avo'
  # end

  ## == Menus ==
  # config.main_menu = -> {
  #   section "Dashboards", icon: "avo/dashboards" do
  #     all_dashboards
  #   end

  #   section "Resources", icon: "avo/resources" do
  #     all_resources
  #   end

  #   section "Tools", icon: "avo/tools" do
  #     all_tools
  #   end
  # }
  # config.profile_menu = -> {
  #   link "Profile", path: "/avo/profile", icon: "heroicons/outline/user-circle"
  # }
end
