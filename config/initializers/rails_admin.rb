# frozen_string_literal: true

# Ignore this file from Zeitwerk autoloading since it's explicitly required
# and doesn't follow Zeitwerk naming conventions
Rails.autoloaders.main.ignore(Rails.root.join('lib/rails_admin/invoice_actions.rb'))

# Load custom Rails Admin actions
require Rails.root.join('lib/rails_admin/invoice_actions')

RailsAdmin.config do |config|
  # Explicitly set asset_source for RailsAdmin 3.x to silence warnings
  config.asset_source = :sprockets

  # Only include User and WindowScheduleRepair models (Window and Tool are nested)
  config.included_models = ['User', 'WindowScheduleRepair', 'Window', 'Tool', 'Invoice']

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

    # Custom invoice actions
    send_invoice
    void_invoice
    mark_paid
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
      field :slug do
        pretty_value do
          bindings[:view].link_to(bindings[:object].slug, bindings[:view].main_app.wrs_show_path(bindings[:object].slug), target: '_blank')
        end
      end
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

  # Configure Invoice model
  config.model 'Invoice' do
    label 'Invoice'
    navigation_label 'Invoices'
    weight 1

    list do
      field :id
      field :name
      field :slug
      field :status
      field :final_status
      field :freshbooks_client_id
      field :included_vat_amount
      field :excluded_vat_amount do
        formatted_value do
          value ? "£#{value.round(2)}" : '-'
        end
      end
      field :is_draft
      field :is_archived
      field :created_at
      field :actions do
        label 'Actions'
        pretty_value do
          invoice = bindings[:object]
          view = bindings[:view]

          view.content_tag(:div, class: 'dropdown') do
            view.content_tag(:button,
              class: 'btn btn-sm btn-secondary dropdown-toggle',
              type: 'button',
              id: "invoice-actions-#{invoice.id}",
              'data-bs-toggle': 'dropdown',
              'aria-expanded': 'false'
            ) do
              'Actions'
            end +
            view.content_tag(:ul,
              class: 'dropdown-menu',
              'aria-labelledby': "invoice-actions-#{invoice.id}"
            ) do
              html = ''
              html += view.content_tag(:li) do
                view.link_to(
                  view.rails_admin.send_invoice_path(model_name: 'invoice', id: invoice.id),
                  method: :post,
                  class: 'dropdown-item',
                  data: { turbo: false }
                ) do
                  view.content_tag(:i, '', class: 'fas fa-paper-plane me-2') + 'Send'
                end
              end

              html += view.content_tag(:li) do
                view.link_to(
                  view.rails_admin.mark_paid_path(model_name: 'invoice', id: invoice.id),
                  method: :post,
                  class: 'dropdown-item',
                  data: { turbo: false }
                ) do
                  view.content_tag(:i, '', class: 'fas fa-check me-2') + 'Mark as Paid'
                end
              end

              html += view.content_tag(:li) do
                view.content_tag(:hr, '', class: 'dropdown-divider')
              end

              html += view.content_tag(:li) do
                view.link_to(
                  view.rails_admin.void_invoice_path(model_name: 'invoice', id: invoice.id),
                  method: :post,
                  class: 'dropdown-item text-danger',
                  data: {
                    turbo: false,
                    confirm: 'Are you sure you want to void this invoice?'
                  }
                ) do
                  view.content_tag(:i, '', class: 'fas fa-ban me-2') + 'Void'
                end
              end

              html.html_safe
            end
          end
        end
      end
    end

    show do
      field :id
      field :name
      field :slug
      field :status
      field :final_status
      field :freshbooks_client_id
      field :included_vat_amount
      field :excluded_vat_amount
      field :total_amount do
        formatted_value do
          bindings[:object].total_amount ? "£#{bindings[:object].total_amount.round(2)}" : '-'
        end
      end
      field :is_draft
      field :is_archived
      field :webflow_item_id
      field :invoice_pdf_link do
        pretty_value do
          if value.present?
            bindings[:view].link_to(value, value, target: '_blank')
          else
            '-'
          end
        end
      end
      field :created_at
      field :updated_at
    end

    edit do
      field :name
      field :slug
      field :status
      field :final_status
      field :freshbooks_client_id
      field :included_vat_amount
      field :excluded_vat_amount
      field :is_draft
      field :is_archived
      field :webflow_item_id
      field :invoice_pdf_link
    end

    create do
      field :name
      field :slug
      field :status
      field :final_status
      field :freshbooks_client_id
      field :included_vat_amount
      field :excluded_vat_amount
      field :is_draft
      field :is_archived
    end

    update do
      field :name
      field :slug
      field :status
      field :final_status
      field :freshbooks_client_id
      field :included_vat_amount
      field :excluded_vat_amount
      field :is_draft
      field :is_archived
      field :webflow_item_id
      field :invoice_pdf_link
    end
  end

end
