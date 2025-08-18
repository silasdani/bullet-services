RailsAdmin.config do |config|
  config.asset_source = :sprockets

  ### Popular gems integration

  ## == Devise ==
  config.authenticate_with do
    # For now, allow all access to Rails Admin
    # TODO: Implement proper authentication
    true
  end
  config.current_user_method do
    # For now, return nil (no user)
    # TODO: Implement proper user detection
    nil
  end

  ## == CancanCan ==
  # config.authorize_with :cancancan

  ## == Pundit ==
  config.authorize_with :pundit

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/railsadminteam/rails_admin/wiki/Base-configuration

  ## == Gravatar integration ==
  ## To disable Gravatar integration in Navigation Bar set to false
  # config.show_gravatar = true

  # Custom branding and styling
  config.main_app_name = ['Bullet Services', 'Admin Panel']
  config.browser_validations = false

  # Navigation configuration
  config.navigation_static_links = {
    'Dashboard' => '/admin',
    'Main Site' => '/'
  }

  # Dashboard configuration
  config.model 'Dashboard' do
    navigation false
    weight -1

    object_label_method do
      'Dashboard'
    end
  end

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end

  # User model configuration
  config.model 'User' do
    navigation_label 'User Management'
    weight 1

    list do
      field :id
      field :email
      field :role
      field :confirmed_at
      field :created_at
    end

    show do
      field :id
      field :email
      field :role
      field :confirmed_at
      field :created_at
      field :updated_at
      field :image
      field :window_schedule_repairs
    end

    edit do
      field :email
      field :password
      field :password_confirmation
      field :role
      field :confirmed_at
      field :image
    end

    create do
      field :email
      field :password
      field :password_confirmation
      field :role
      field :image
    end
  end

  # Window model configuration
  config.model 'Window' do
    navigation_label 'Window Management'
    weight 2

    list do
      field :id
      field :location
      field :window_schedule_repair
      field :created_at
    end

    show do
      field :id
      field :location
      field :window_schedule_repair
      field :image
      field :created_at
      field :updated_at
    end

    edit do
      field :location
      field :window_schedule_repair
      field :image
    end

    create do
      field :location
      field :window_schedule_repair
      field :image
    end
  end

  # WindowScheduleRepair model configuration
  config.model 'WindowScheduleRepair' do
    navigation_label 'Repair Management'
    weight 3

    list do
      field :id
      field :name
      field :slug
      field :status
      field :user
      field :total_vat_included_price
      field :created_at
    end

    show do
      field :id
      field :name
      field :slug
      field :status
      field :address
      field :total_vat_included_price
      field :user
      field :windows
      field :images
      field :created_at
      field :updated_at
    end

    edit do
      field :name
      field :slug
      field :status
      field :address
      field :total_vat_included_price
      field :user
      field :images
    end

    create do
      field :name
      field :slug
      field :status
      field :address
      field :total_vat_included_price
      field :user
      field :images
    end
  end
end
