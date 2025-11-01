# frozen_string_literal: true

RailsAdmin.config do |config|
  # Explicitly set asset_source for RailsAdmin 3.x to silence warnings
  config.asset_source = :sprockets

  # Only include User and WindowScheduleRepair models (Window and Tool are nested)
  config.included_models = ['User', 'WindowScheduleRepair', 'Window', 'Tool']

  # Authenticate: ensure user is logged in via Devise session
  config.authenticate_with do
    redirect_to main_app.new_user_session_path unless request.env["warden"]&.user(:user).present?
  end

  # Authorize: only admins/superadmins allowed
  config.authorize_with do
    redirect_to main_app.root_path, alert: "You are not authorized to access this page." unless current_user&.is_admin?
  end

  config.current_user_method(&:current_user)

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
  end

  # Configure User model
  config.model 'User' do
    label 'Users'
    navigation_label 'Management'
    weight 1

    list do
      field :id
      field :email
      field :name
      field :role
      field :created_at
    end

    show do
      field :id
      field :email
      field :name
      field :role
      field :created_at
      field :updated_at
    end

    edit do
      field :email
      field :name
      field :password
      field :password_confirmation
      field :role
    end
  end

  # Configure WindowScheduleRepair model (WRS)
  config.model 'WindowScheduleRepair' do
    label 'WRS'
    navigation_label 'Management'
    weight 2

    list do
      field :id
      field :reference_number
      field :name
      field :address
      field :flat_number
      field :status
      field :grand_total
      field :user
      field :created_at
    end

    show do
      field :id
      field :reference_number
      field :name
      field :slug
      field :address
      field :flat_number
      field :details
      field :status
      field :user
      field :subtotal do
        formatted_value do
          bindings[:object].subtotal.round(2)
        end
      end
      field :vat_amount do
        formatted_value do
          bindings[:object].vat_amount.round(2)
        end
      end
      field :total_vat_excluded_price
      field :total_vat_included_price
      field :grand_total
      field :is_draft
      field :is_archived
      field :webflow_item_id
      field :created_at
      field :updated_at
      field :deleted_at
      field :windows do
        pretty_value do
          if bindings[:object].windows.any?
            bindings[:view].content_tag(:div, class: 'windows-display') do
              bindings[:object].windows.map.with_index do |window, idx|
                content = bindings[:view].content_tag(:h4, "Window #{idx + 1}: #{window.location}", style: 'margin: 20px 0 10px 0;')
                if window.image.attached?
                  content += bindings[:view].tag(:img, { src: window.image.url, style: 'max-width: 300px; max-height: 300px; display: block; margin: 10px 0;' })
                elsif window.effective_image_url.present?
                  content += bindings[:view].tag(:img, { src: window.effective_image_url, style: 'max-width: 300px; max-height: 300px; display: block; margin: 10px 0;' })
                end
                if window.tools.any?
                  content += bindings[:view].content_tag(:ul, style: 'margin: 10px 0; padding-left: 20px;') do
                    window.tools.map do |tool|
                      bindings[:view].content_tag(:li, "#{tool.name}: £#{tool.price}", style: 'margin: 5px 0;')
                    end.join.html_safe
                  end
                end
                content
              end.join.html_safe
            end
          else
            'No windows'
          end
        end
      end
    end

    edit do
      field :user
      field :name
      field :address
      field :flat_number
      field :details
      field :status
      field :windows do
        nested_form do
        end
      end
    end

    create do
      field :user
      field :name
      field :address
      field :flat_number
      field :details
      field :status
      field :windows do
        nested_form do
        end
      end
    end

    update do
      field :user
      field :name
      field :address
      field :flat_number
      field :details
      field :status
      field :windows do
        nested_form do
        end
      end
    end
  end

  # Configure Window model (nested in WRS, not visible in main navigation)
  config.model 'Window' do
    visible false
    object_label_method :location

    show do
      field :id
      field :location
      field :image_url do
        pretty_value do
          if bindings[:object].image_url.present?
            bindings[:view].tag(:img, { src: bindings[:object].image_url, style: 'max-width: 500px; max-height: 500px;' }) +
            bindings[:view].tag(:br) +
            bindings[:view].link_to(bindings[:object].image_url, bindings[:object].image_url, target: '_blank')
          else
            'No image available'
          end
        end
      end
      field :effective_image_url do
        pretty_value do
          if bindings[:object].effective_image_url.present?
            bindings[:view].tag(:img, { src: bindings[:object].effective_image_url, style: 'max-width: 500px; max-height: 500px;' }) +
            bindings[:view].tag(:br) +
            bindings[:view].link_to(bindings[:object].effective_image_url, bindings[:object].effective_image_url, target: '_blank')
          else
            'No image available'
          end
        end
      end
      field :tools
      field :created_at
      field :updated_at
    end

    list do
      field :id
      field :location
      field :tools_count do
        formatted_value do
          bindings[:object].tools.count
        end
      end
    end
  end

  # Configure Tool model (nested in Window, not visible in main navigation)
  config.model 'Tool' do
    visible false
    object_label_method :name
  end

end
