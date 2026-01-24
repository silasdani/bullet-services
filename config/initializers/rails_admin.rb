# frozen_string_literal: true

# Ignore this file from Zeitwerk autoloading since it's explicitly required
# and doesn't follow Zeitwerk naming conventions
Rails.autoloaders.main.ignore(Rails.root.join('lib/rails_admin/invoice_lifecycle.rb'))
Rails.autoloaders.main.ignore(Rails.root.join('lib/rails_admin/invoice_actions.rb'))
Rails.autoloaders.main.ignore(Rails.root.join('lib/rails_admin/buildings_grid_action.rb'))
Rails.autoloaders.main.ignore(Rails.root.join('lib/rails_admin/wrs_grid_action.rb'))
Rails.autoloaders.main.ignore(Rails.root.join('lib/rails_admin/custom_dashboard_action.rb'))

# Load custom Rails Admin actions and lifecycle rules
require Rails.root.join('lib/rails_admin/invoice_lifecycle')
require Rails.root.join('lib/rails_admin/invoice_actions')
require Rails.root.join('lib/rails_admin/buildings_grid_action')
require Rails.root.join('lib/rails_admin/wrs_grid_action')
require Rails.root.join('lib/rails_admin/custom_dashboard_action')

RailsAdmin.config do |config|
  # Explicitly set asset_source for RailsAdmin 3.x to silence warnings
  config.asset_source = :sprockets

  # Only include User and WindowScheduleRepair models (Window and Tool are nested)
  config.included_models = ['User', 'WindowScheduleRepair', 'Window', 'Tool', 'Invoice', 'Building']

  # Authenticate: ensure user is logged in via Devise session
  config.authenticate_with do
    redirect_to main_app.new_user_session_path unless request.env["warden"]&.user(:user).present?
  end

  # Authorize: only admins/superadmins allowed
  config.authorize_with do
    redirect_to main_app.root_path, alert: "You are not authorized to access this page." unless current_user&.is_admin?
  end

  config.current_user_method(&:current_user)

  # Set pagination to 10 items per page
  config.default_items_per_page = 10

  config.actions do
    dashboard do
      controller do
        proc do
          # Set all instance variables that the view expects
          # Outstanding invoices scope (unpaid, not voided, not draft)
          outstanding_scope = Invoice.where(is_draft: false)
                                     .where.not(final_status: ['paid', 'voided', 'voided + email sent'])

          # Load outstanding invoices with freshbooks_invoices for display (limit 10)
          @outstanding_invoices = outstanding_scope.includes(:freshbooks_invoices)
                                                   .order(created_at: :desc)
                                                   .limit(10)
                                                   .to_a

          # Calculate outstanding count
          @outstanding_count = outstanding_scope.count

          # Load all outstanding invoices once for calculations
          today = Date.current
          all_outstanding = outstanding_scope.includes(:freshbooks_invoices).to_a

          # Calculate outstanding amount
          @outstanding_amount = all_outstanding.sum { |invoice| (invoice.total_amount || 0).to_f }

          # Calculate overdue invoices
          overdue_invoices = all_outstanding.select do |invoice|
            freshbooks_invoice = invoice.freshbooks_invoices.first
            freshbooks_invoice&.due_date && freshbooks_invoice.due_date < today
          end

          @overdue_count = overdue_invoices.count
          @overdue_amount = overdue_invoices.sum { |invoice| (invoice.total_amount || 0).to_f }

          # Ensure all variables have default values
          @outstanding_invoices ||= []
          @outstanding_count ||= 0
          @outstanding_amount ||= 0.0
          @overdue_count ||= 0
          @overdue_amount ||= 0.0

          render template: 'rails_admin/main/dashboard'
        end
      end
    end
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit

    # Customize delete action to skip callbacks for invoices
    delete do
      controller do
        proc do
          if @object.is_a?(Invoice)
            # Delete associated freshbooks_invoices without callbacks
            @object.freshbooks_invoices.delete_all

            # Use delete instead of destroy to skip callbacks
            @object.delete

            flash[:success] = "Invoice deleted successfully (callbacks skipped)"
            redirect_to rails_admin.index_path(model_name: 'invoice')
          else
            # Default behavior for other models
            @object.destroy
            flash[:success] = I18n.t('admin.flash.successful', name: @model_config.label, action: I18n.t('admin.actions.delete.done'))
            redirect_to back_or_index
          end
        end
      end
    end

    # Custom invoice actions
    send_invoice
    void_invoice
    void_invoice_with_email
    apply_discount
    mark_paid

    # Custom grid view actions - configured to show in navigation sidebar
    buildings_grid do
      show_in_navigation true
      navigation_label 'Grid Views'
    end

    wrs_grid do
      show_in_navigation true
      navigation_label 'Grid Views'
    end
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
      field :role do
        pretty_value do
          user = bindings[:object]
          role = user.role
          role_class = case role
          when 'client'
            'badge bg-primary'
          when 'surveyor'
            'badge bg-success'
          when 'admin'
            'badge bg-warning text-dark'
          when 'super_admin'
            'badge bg-danger'
          else
            'badge bg-secondary'
          end

          role_label = case role
          when 'client'
            'Client'
          when 'surveyor'
            'Surveyor'
          when 'admin'
            'Admin'
          when 'super_admin'
            'Super Admin'
          else
            role.titleize
          end

          bindings[:view].content_tag(:span, role_label, class: role_class)
        end
      end
      field :created_at
    end

    show do
      field :id
      field :email
      field :name
      field :role do
        pretty_value do
          user = bindings[:object]
          role = user.role
          role_class = case role
          when 'client'
            'badge bg-primary'
          when 'surveyor'
            'badge bg-success'
          when 'admin'
            'badge bg-warning text-dark'
          when 'super_admin'
            'badge bg-danger'
          else
            'badge bg-secondary'
          end

          role_label = case role
          when 'client'
            'Client'
          when 'surveyor'
            'Surveyor'
          when 'admin'
            'Admin'
          when 'super_admin'
            'Super Admin'
          else
            role.titleize
          end

          bindings[:view].content_tag(:span, role_label, class: role_class)
        end
      end
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
      field :name do
        pretty_value do
          bindings[:view].link_to(bindings[:object].name, bindings[:view].main_app.wrs_show_path(bindings[:object].slug), target: '_blank')
        end
      end
      field :address
      field :flat_number
      field :status do
        pretty_value do
          wrs = bindings[:object]
          badges = []

          # Priority: archived > draft > status
          if wrs.is_archived
            badges << bindings[:view].content_tag(:span, 'Archived', class: 'badge bg-dark')
          elsif wrs.is_draft
            badges << bindings[:view].content_tag(:span, 'Draft', class: 'badge bg-secondary')
          else
            status = wrs.status || 'pending'
            status_class = case status
            when 'pending'
              'badge bg-warning text-dark'
            when 'approved'
              'badge bg-success'
            when 'rejected'
              'badge bg-danger'
            when 'completed'
              'badge bg-info'
            else
              'badge bg-secondary'
            end

            status_label = status.titleize
            badges << bindings[:view].content_tag(:span, status_label, class: status_class)
          end

          badges.join.html_safe
        end
      end
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
      field :status do
        pretty_value do
          wrs = bindings[:object]
          badges = []

          # Priority: archived > draft > status
          if wrs.is_archived
            badges << bindings[:view].content_tag(:span, 'Archived', class: 'badge bg-dark')
          elsif wrs.is_draft
            badges << bindings[:view].content_tag(:span, 'Draft', class: 'badge bg-secondary')
          else
            status = wrs.status || 'pending'
            status_class = case status
            when 'pending'
              'badge bg-warning text-dark'
            when 'approved'
              'badge bg-success'
            when 'rejected'
              'badge bg-danger'
            when 'completed'
              'badge bg-info'
            else
              'badge bg-secondary'
            end

            status_label = status.titleize
            badges << bindings[:view].content_tag(:span, status_label, class: status_class)
          end

          badges.join.html_safe
        end
      end
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

    # Optimize queries by eager loading associations
    scope { Invoice.includes(:freshbooks_invoices) }

    list do
      # Filters will be automatically available based on ransackable_attributes in the model
      # Name
      field :name do
        label 'Name'
      end

      # PDF
      field :invoice_pdf do
        label 'PDF'
        pretty_value do
          invoice = bindings[:object]
          if invoice.invoice_pdf.attached?
            pdf_url = invoice.invoice_pdf.url
            bindings[:view].link_to(
              bindings[:view].content_tag(:i, '', class: 'fas fa-file-pdf me-1') + 'View PDF',
              pdf_url,
              target: '_blank',
              class: 'btn btn-sm btn-outline-primary',
              style: 'text-decoration: none;'
            )
          elsif invoice.invoice_pdf_link.present?
            bindings[:view].link_to(
              bindings[:view].content_tag(:i, '', class: 'fas fa-file-pdf me-1') + 'View PDF (Link)',
              invoice.invoice_pdf_link,
              target: '_blank',
              class: 'btn btn-sm btn-outline-secondary',
              style: 'text-decoration: none;'
            )
          else
            bindings[:view].content_tag(:span, 'No PDF', class: 'text-muted')
          end
        end
      end


      # Status
      field :final_status do
        label 'Status'
        read_only true
        pretty_value do
          invoice = bindings[:object]
          status = invoice.final_status || 'draft'
          status_class = case status.downcase
          when 'paid'
            'badge bg-success'
          when 'sent', 'viewed', 'sent - awaiting payment'
            'badge bg-info'
          when 'draft'
            'badge bg-secondary'
          when 'voided', 'voided + email sent'
            'badge bg-danger'
          when 'overdue'
            'badge bg-warning text-dark'
          else
            'badge bg-primary'
          end

          status_label = case status.downcase
          when 'paid'
            'Paid'
          when 'sent', 'viewed', 'sent - awaiting payment'
            'Sent'
          when 'draft'
            'Draft'
          when 'voided'
            'Voided'
          when 'voided + email sent'
            'Voided + Emailed'
          when 'overdue'
            'Overdue'
          else
            status.titleize
          end

          bindings[:view].content_tag(:span, status_label, class: status_class)
        end
      end


      # VAT Included Amount (for filtering and sorting, hidden from list display)
      field :included_vat_amount do
        label 'VAT incl (£)'
        # hide
        filterable true
        sortable true
        # Allow sorting even when hidden
        searchable true
      end

      # Submit (Actions dropdown)
      field :submit do
        label 'Submit'
        pretty_value do
          invoice = bindings[:object]
          view = bindings[:view]
          invoice_id = invoice.id

          # Modals HTML - build as SafeBuffer
          modals_html = ActiveSupport::SafeBuffer.new

          # Modal 1: Send Invoice
          modals_html << view.content_tag(:div,
            class: 'modal fade',
            id: "send-invoice-modal-#{invoice_id}",
            tabindex: '-1',
            'aria-labelledby': "send-invoice-modal-label-#{invoice_id}",
            'aria-hidden': 'true',
            title: '',
            style: 'display: none;'
          ) do
            view.content_tag(:div, class: 'modal-dialog modal-dialog-centered') do
              view.content_tag(:div, class: 'modal-content') do
                view.content_tag(:div, class: 'modal-header') do
                  view.content_tag(:h5, class: 'modal-title', id: "send-invoice-modal-label-#{invoice_id}") do
                    view.content_tag(:i, '', class: 'fas fa-paper-plane me-2') + 'Send Invoice'
                  end +
                  view.content_tag(:button, '', type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close')
                end +
                view.content_tag(:div, class: 'modal-body') do
                  invoice_name = invoice.name || invoice.slug || 'this invoice'
                  view.content_tag(:p, "Are you sure you want to send invoice \"#{invoice_name}\" to the client?", style: 'word-wrap: break-word; overflow-wrap: break-word; max-width: 100%;')
                end +
                view.content_tag(:div, class: 'modal-footer') do
                  view.content_tag(:button, 'Cancel', type: 'button', class: 'btn btn-secondary', 'data-bs-dismiss': 'modal') +
                  view.link_to(
                    view.rails_admin.send_invoice_path(model_name: 'invoice', id: invoice_id),
                    method: :post,
                    class: 'btn btn-primary',
                    data: { turbo: false }
                  ) do
                    view.content_tag(:i, '', class: 'fas fa-paper-plane me-1') + 'Send Invoice'
                  end
                end
              end
            end
          end

          # Modal 2: Delete (Void)
          modals_html << view.content_tag(:div,
            class: 'modal fade',
            id: "delete-invoice-modal-#{invoice_id}",
            tabindex: '-1',
            'aria-labelledby': "delete-invoice-modal-label-#{invoice_id}",
            'aria-hidden': 'true',
            title: '',
            style: 'display: none;'
          ) do
            view.content_tag(:div, class: 'modal-dialog modal-dialog-centered') do
              view.content_tag(:div, class: 'modal-content') do
                view.content_tag(:div, class: 'modal-header') do
                  view.content_tag(:h5, class: 'modal-title', id: "delete-invoice-modal-label-#{invoice_id}") do
                    view.content_tag(:i, '', class: 'fas fa-trash me-2') + 'Delete Invoice'
                  end +
                  view.content_tag(:button, '', type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close')
                end +
                view.content_tag(:div, class: 'modal-body') do
                  invoice_name = invoice.name || invoice.slug || 'this invoice'
                  view.content_tag(:p, class: 'text-danger', style: 'word-wrap: break-word; overflow-wrap: break-word; max-width: 100%;') do
                    view.content_tag(:strong, 'Warning: ') +
                    "Are you sure you want to void invoice \"#{invoice_name}\"? This action cannot be undone."
                  end
                end +
                view.content_tag(:div, class: 'modal-footer') do
                  view.content_tag(:button, 'Cancel', type: 'button', class: 'btn btn-secondary', 'data-bs-dismiss': 'modal') +
                  view.link_to(
                    view.rails_admin.void_invoice_path(model_name: 'invoice', id: invoice_id),
                    method: :post,
                    class: 'btn btn-danger',
                    data: { turbo: false }
                  ) do
                    view.content_tag(:i, '', class: 'fas fa-trash me-1') + 'Delete Invoice'
                  end
                end
              end
            end
          end

          # Modal 3: Delete + Void Email
          modals_html << view.content_tag(:div,
            class: 'modal fade',
            id: "delete-void-email-modal-#{invoice_id}",
            tabindex: '-1',
            'aria-labelledby': "delete-void-email-modal-label-#{invoice_id}",
            'aria-hidden': 'true',
            title: '',
            style: 'display: none;'
          ) do
            view.content_tag(:div, class: 'modal-dialog modal-dialog-centered') do
              view.content_tag(:div, class: 'modal-content') do
                view.content_tag(:div, class: 'modal-header') do
                  view.content_tag(:h5, class: 'modal-title', id: "delete-void-email-modal-label-#{invoice_id}") do
                    view.content_tag(:i, '', class: 'fas fa-ban me-2') + 'Delete & Send Voidance Email'
                  end +
                  view.content_tag(:button, '', type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close')
                end +
                view.content_tag(:div, class: 'modal-body') do
                  invoice_name = invoice.name || invoice.slug || 'this invoice'
                  view.content_tag(:p, class: 'text-danger', style: 'word-wrap: break-word; overflow-wrap: break-word; max-width: 100%;') do
                    view.content_tag(:strong, 'Warning: ') +
                    "Are you sure you want to void invoice \"#{invoice_name}\" and send a voidance email to the client? This action cannot be undone."
                  end
                end +
                view.content_tag(:div, class: 'modal-footer') do
                  view.content_tag(:button, 'Cancel', type: 'button', class: 'btn btn-secondary', 'data-bs-dismiss': 'modal') +
                  view.link_to(
                    view.rails_admin.void_invoice_with_email_path(model_name: 'invoice', id: invoice_id),
                    method: :post,
                    class: 'btn btn-danger',
                    data: { turbo: false }
                  ) do
                    view.content_tag(:i, '', class: 'fas fa-ban me-1') + 'Delete & Send Email'
                  end
                end
              end
            end
          end

          # Modal 4: Apply Discount
          modals_html << view.content_tag(:div,
            class: 'modal fade',
            id: "apply-discount-modal-#{invoice_id}",
            tabindex: '-1',
            'aria-labelledby': "apply-discount-modal-label-#{invoice_id}",
            'aria-hidden': 'true',
            title: '',
            style: 'display: none;'
          ) do
            view.content_tag(:div, class: 'modal-dialog modal-dialog-centered') do
              view.content_tag(:div, class: 'modal-content') do
                view.content_tag(:div, class: 'modal-header') do
                  view.content_tag(:h5, class: 'modal-title', id: "apply-discount-modal-label-#{invoice_id}") do
                    view.content_tag(:i, '', class: 'fas fa-percent me-2') + 'Apply Discount'
                  end +
                  view.content_tag(:button, '', type: 'button', class: 'btn-close', 'data-bs-dismiss': 'modal', 'aria-label': 'Close')
                end +
                view.content_tag(:div, class: 'modal-body') do
                  invoice_name = invoice.name || invoice.slug || 'this invoice'
                  view.content_tag(:p, style: 'word-wrap: break-word; overflow-wrap: break-word; max-width: 100%;') do
                    "Are you sure you want to apply a 10% discount to invoice \"#{invoice_name}\"? This will update all line items in FreshBooks."
                  end
                end +
                view.content_tag(:div, class: 'modal-footer') do
                  view.content_tag(:button, 'Cancel', type: 'button', class: 'btn btn-secondary', 'data-bs-dismiss': 'modal') +
                  view.link_to(
                    view.rails_admin.apply_discount_path(model_name: 'invoice', id: invoice_id),
                    method: :post,
                    class: 'btn btn-primary',
                    data: { turbo: false }
                  ) do
                    view.content_tag(:i, '', class: 'fas fa-percent me-1') + 'Apply 10% Discount'
                  end
                end
              end
            end
          end

          # Dropdown with modals
          dropdown_html = view.content_tag(:div, class: 'dropdown', 'data-bs-boundary': 'viewport', 'data-bs-offset': '0,8') do
            view.content_tag(:button,
              class: 'btn btn-sm btn-primary dropdown-toggle',
              type: 'button',
              id: "invoice-submit-#{invoice_id}",
              'data-bs-toggle': 'dropdown',
              'data-bs-auto-close': 'true',
              'data-bs-boundary': 'viewport',
              'data-bs-offset': '0,8',
              'data-bs-placement': 'auto',
              'aria-expanded': 'false'
            ) do
              view.content_tag(:i, '', class: 'fas fa-cog me-1') + 'Actions'
            end +
            view.content_tag(:ul,
              class: 'dropdown-menu',
              'aria-labelledby': "invoice-submit-#{invoice_id}"
            ) do
              html = ActiveSupport::SafeBuffer.new

              # 1. Send
              html << view.content_tag(:li) do
                view.content_tag(:a,
                  href: '#',
                  class: 'dropdown-item',
                  'data-bs-toggle': 'modal',
                  'data-bs-target': "#send-invoice-modal-#{invoice_id}"
                ) do
                  view.content_tag(:i, '', class: 'fas fa-paper-plane me-2') + 'Send'
                end
              end

              # 2. Delete (Void)
              html << view.content_tag(:li) do
                view.content_tag(:a,
                  href: '#',
                  class: 'dropdown-item',
                  'data-bs-toggle': 'modal',
                  'data-bs-target': "#delete-invoice-modal-#{invoice_id}"
                ) do
                  view.content_tag(:i, '', class: 'fas fa-trash me-2') + 'Delete'
                end
              end

              # 3. Delete + Void Email
              html << view.content_tag(:li) do
                view.content_tag(:a,
                  href: '#',
                  class: 'dropdown-item',
                  'data-bs-toggle': 'modal',
                  'data-bs-target': "#delete-void-email-modal-#{invoice_id}"
                ) do
                  view.content_tag(:i, '', class: 'fas fa-ban me-2') + 'Delete + Void Email'
                end
              end

              # Divider
              html << view.content_tag(:li) do
                view.content_tag(:hr, '', class: 'dropdown-divider')
              end

              # 4. Apply Discount
              html << view.content_tag(:li) do
                view.content_tag(:a,
                  href: '#',
                  class: 'dropdown-item',
                  'data-bs-toggle': 'modal',
                  'data-bs-target': "#apply-discount-modal-#{invoice_id}"
                ) do
                  view.content_tag(:i, '', class: 'fas fa-percent me-2') + 'Apply Discount (10%)'
                end
              end

              html
            end
          end

          # Add JavaScript to fix dropdown positioning by moving menu to body
          script_html = view.content_tag(:script, type: 'text/javascript') do
            <<~JS.html_safe
              (function() {
                function initDropdowns() {
                  var dropdowns = document.querySelectorAll('.rails_admin .table tbody td .dropdown');
                  dropdowns.forEach(function(dropdown) {
                    var button = dropdown.querySelector('.dropdown-toggle');
                    var menu = dropdown.querySelector('.dropdown-menu');
                    if (button && menu && !dropdown.dataset.positioningInitialized) {
                      dropdown.dataset.positioningInitialized = 'true';
                      var originalParent = menu.parentNode;
                      var isMovedToBody = false;

                      function positionMenu() {
                        if (!isMovedToBody) return;

                        // Get button position relative to viewport
                        var rect = button.getBoundingClientRect();

                        // Ensure menu is visible to get accurate dimensions
                        menu.style.display = 'block';
                        menu.style.visibility = 'visible';

                        // Force reflow to get accurate dimensions
                        var menuHeight = menu.offsetHeight || menu.scrollHeight || 200;
                        var menuWidth = menu.offsetWidth || menu.scrollWidth || 180;

                        var viewportHeight = window.innerHeight;
                        var viewportWidth = window.innerWidth;
                        var spaceBelow = viewportHeight - rect.bottom;
                        var spaceAbove = rect.top;
                        var padding = 8;

                        // Calculate horizontal position (account for viewport scroll)
                        var left = rect.left;
                        // Ensure menu doesn't go off right edge
                        if (left + menuWidth > viewportWidth) {
                          left = viewportWidth - menuWidth - padding;
                        }
                        // Ensure menu doesn't go off left edge
                        if (left < padding) {
                          left = padding;
                        }

                        // Calculate vertical position
                        var top;
                        if (spaceBelow >= menuHeight + padding) {
                          // Enough space below - position below button
                          top = rect.bottom + padding;
                        } else if (spaceAbove >= menuHeight + padding) {
                          // Not enough space below, but enough above - position above button
                          top = rect.top - menuHeight - padding;
                        } else {
                          // Not enough space either way - fit within viewport
                          if (spaceBelow > spaceAbove) {
                            // More space below, position at bottom of viewport
                            top = Math.max(padding, viewportHeight - menuHeight - padding);
                          } else {
                            // More space above, position at top of viewport
                            top = padding;
                          }
                        }

                        menu.style.top = top + 'px';
                        menu.style.left = left + 'px';
                        menu.style.right = 'auto';
                        menu.style.bottom = 'auto';
                        menu.style.transform = 'none'; // Remove any Bootstrap transforms
                      }

                      // Don't move during show - let Bootstrap show it first
                      dropdown.addEventListener('show.bs.dropdown', function(e) {
                        // Just prepare, don't move yet
                      });

                      // Move menu to body AFTER Bootstrap has shown it
                      dropdown.addEventListener('shown.bs.dropdown', function(e) {
                        // Move menu to body to escape table stacking context
                        if (!isMovedToBody) {
                          document.body.appendChild(menu);
                          isMovedToBody = true;
                        }

                        // Set styles for fixed positioning
                        menu.style.position = 'fixed';
                        menu.style.zIndex = '100000';
                        menu.style.display = 'block';
                        menu.style.visibility = 'visible';
                        menu.style.opacity = '1';
                        menu.style.marginTop = '0';
                        menu.style.marginBottom = '0';
                        menu.style.transform = 'none'; // Remove Bootstrap transforms
                        menu.style.pointerEvents = 'auto';

                        // Position menu after a brief delay to ensure dimensions are calculated
                        setTimeout(function() {
                          positionMenu();
                        }, 0);
                      });

                      // Move menu back to original position when closed
                      dropdown.addEventListener('hide.bs.dropdown', function(e) {
                        // Don't move back yet - wait for hidden event
                      });

                      dropdown.addEventListener('hidden.bs.dropdown', function(e) {
                        if (isMovedToBody && originalParent) {
                          originalParent.appendChild(menu);
                          isMovedToBody = false;
                          menu.style.position = '';
                          menu.style.zIndex = '';
                          menu.style.top = '';
                          menu.style.left = '';
                          menu.style.right = '';
                          menu.style.bottom = '';
                        }
                      });

                      // Reposition on scroll
                      var scrollHandler = function() {
                        if (isMovedToBody && dropdown.classList.contains('show')) {
                          positionMenu();
                        }
                      };
                      window.addEventListener('scroll', scrollHandler, true);
                      window.addEventListener('resize', scrollHandler);
                    }
                  });
                }

                if (document.readyState === 'loading') {
                  document.addEventListener('DOMContentLoaded', initDropdowns);
                } else {
                  initDropdowns();
                }

                // Re-initialize after Turbo navigation
                if (typeof Turbo !== 'undefined') {
                  document.addEventListener('turbo:load', initDropdowns);
                }
              })();
            JS
          end

          result = dropdown_html + modals_html + script_html
          result.html_safe
        end
      end

      # ClientID
      field :freshbooks_client_id do
        label 'Client ID'
      end

      # Job
      field :job do
        label 'Job'
      end

      # Generated by (created date)
      field :created_at do
        label 'Created'
        formatted_value do
          value ? value.strftime('%d %b %Y') : '-'
        end
      end

      # Due Date (from FreshbooksInvoice)
      field :due_date do
        label 'Due Date'
        pretty_value do
          invoice = bindings[:object]
          freshbooks_invoice = invoice.freshbooks_invoices.first
          if freshbooks_invoice&.due_date
            due_date = freshbooks_invoice.due_date
            is_overdue = due_date < Date.current && invoice.status != 'paid'
            css_class = is_overdue ? 'text-danger fw-bold' : ''
            bindings[:view].content_tag(:span, due_date.strftime('%d %b %Y'), class: css_class)
          else
            bindings[:view].content_tag(:span, '-', class: 'text-muted')
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
      field :job
      field :flat_address
      field :generated_by
      field :wrs_link do
        pretty_value do
          if value.present?
            bindings[:view].link_to(value, value, target: '_blank')
          else
            '-'
          end
        end
      end
      field :included_vat_amount
      field :excluded_vat_amount
      field :total_amount do
        formatted_value do
          bindings[:object].total_amount ? "£#{bindings[:object].total_amount.round(2)}" : '-'
        end
      end
      field :status_color
      field :is_draft
      field :is_archived
      field :webflow_collection_id
      field :webflow_item_id
      field :webflow_created_on
      field :webflow_updated_on
      field :webflow_published_on
      field :invoice_pdf do
        label 'PDF Attachment'
        pretty_value do
          invoice = bindings[:object]
          if invoice.invoice_pdf.attached?
            pdf_url = invoice.invoice_pdf.url
            blob = invoice.invoice_pdf.blob
            file_size = blob.byte_size
            file_size_mb = (file_size / 1_000_000.0).round(2)
            file_size_kb = (file_size / 1_000.0).round(2)
            size_display = file_size_mb >= 1 ? "#{file_size_mb} MB" : "#{file_size_kb} KB"

            html = ActiveSupport::SafeBuffer.new

            # Download button
            html << bindings[:view].link_to(
              bindings[:view].content_tag(:i, '', class: 'fas fa-download me-1') + 'Download PDF',
              pdf_url,
              target: '_blank',
              class: 'btn btn-primary mb-2',
              style: 'text-decoration: none; display: inline-block;'
            )

            # View in new tab button (use Rails URL helper to serve PDF properly)
            pdf_view_url = Rails.application.routes.url_helpers.rails_blob_path(blob, disposition: 'inline', only_path: true)
            html << bindings[:view].link_to(
              bindings[:view].content_tag(:i, '', class: 'fas fa-external-link-alt me-1') + 'View PDF',
              pdf_view_url,
              target: '_blank',
              class: 'btn btn-outline-primary mb-2',
              style: 'text-decoration: none; display: inline-block; margin-left: 10px;'
            )

            # File info
            html << bindings[:view].content_tag(:div, class: 'mt-2') do
              bindings[:view].content_tag(:p, class: 'mb-1') do
                bindings[:view].content_tag(:strong, 'Filename: ') + blob.filename.to_s
              end +
              bindings[:view].content_tag(:p, class: 'mb-1') do
                bindings[:view].content_tag(:strong, 'Size: ') + size_display
              end +
              bindings[:view].content_tag(:p, class: 'mb-1') do
                bindings[:view].content_tag(:strong, 'Content Type: ') + (blob.content_type || 'application/pdf')
              end +
              (blob.created_at ? bindings[:view].content_tag(:p, class: 'mb-1') do
                bindings[:view].content_tag(:strong, 'Uploaded: ') + blob.created_at.strftime('%d %b %Y %H:%M')
              end : '')
            end

            # Embedded PDF viewer
            html << bindings[:view].content_tag(:div, class: 'mt-3') do
              bindings[:view].content_tag(:h5, 'PDF Preview:', class: 'mb-2') +
              bindings[:view].content_tag(:iframe,
                '',
                src: pdf_url,
                width: '100%',
                height: '600px',
                style: 'border: 1px solid #ddd; border-radius: 4px;',
                frameborder: '0'
              )
            end

            html
          else
            bindings[:view].content_tag(:div, class: 'alert alert-info') do
              bindings[:view].content_tag(:i, '', class: 'fas fa-info-circle me-1') + 'No PDF attached to this invoice.'
            end
          end
        end
      end
      field :invoice_pdf_link do
        label 'PDF Link (Legacy)'
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
      field :job
      field :flat_address
      field :generated_by
      field :wrs_link
      field :included_vat_amount
      field :excluded_vat_amount
      field :status_color
      field :is_draft
      field :is_archived
      field :webflow_collection_id
      field :webflow_item_id
      field :webflow_created_on
      field :webflow_updated_on
      field :webflow_published_on
      field :invoice_pdf do
        label 'PDF File'
      end
      field :invoice_pdf_link do
        label 'PDF Link (Legacy)'
      end
    end

    create do
      field :name
      field :slug
      field :status
      field :final_status
      field :freshbooks_client_id
      field :job
      field :flat_address
      field :generated_by
      field :wrs_link
      field :included_vat_amount
      field :excluded_vat_amount
      field :status_color
      field :is_draft
      field :is_archived
      field :webflow_collection_id
      field :webflow_item_id
      field :webflow_created_on
      field :webflow_updated_on
      field :webflow_published_on
      field :invoice_pdf do
        label 'PDF File'
      end
      field :invoice_pdf_link do
        label 'PDF Link (Legacy)'
      end
    end

    update do
      field :name
      field :slug
      field :status
      field :final_status
      field :freshbooks_client_id
      field :job
      field :flat_address
      field :generated_by
      field :wrs_link
      field :included_vat_amount
      field :excluded_vat_amount
      field :status_color
      field :is_draft
      field :is_archived
      field :webflow_collection_id
      field :webflow_item_id
      field :webflow_created_on
      field :webflow_updated_on
      field :webflow_published_on
      field :invoice_pdf do
        label 'PDF File'
      end
      field :invoice_pdf_link do
        label 'PDF Link (Legacy)'
      end
    end
  end

  # Configure Building model
  config.model 'Building' do
    label 'Building'
    navigation_label 'Management'
    weight 3

    # Optimize queries by eager loading associations
    scope { Building.includes(:window_schedule_repairs).where(deleted_at: nil) }

    list do
      field :id
      field :name
      field :full_address do
        label 'Address'
        pretty_value do
          bindings[:object].full_address
        end
      end
      field :wrs_count do
        label 'WRS Count'
        pretty_value do
          if bindings[:object].association(:window_schedule_repairs).loaded?
            bindings[:object].window_schedule_repairs.size
          else
            bindings[:object].window_schedule_repairs.count
          end
        end
      end
      field :created_at
    end

    show do
      field :id
      field :name
      field :street
      field :city
      field :zipcode
      field :country
      field :full_address do
        label 'Full Address'
        pretty_value do
          bindings[:object].full_address
        end
      end
      field :address_string do
        label 'Address String'
        pretty_value do
          bindings[:object].address_string
        end
      end
      field :display_name do
        label 'Display Name'
        pretty_value do
          bindings[:object].display_name
        end
      end
      field :window_schedule_repairs do
        label 'WRS'
        pretty_value do
          if bindings[:object].window_schedule_repairs.any?
            bindings[:view].content_tag(:div, class: 'wrs-list') do
              bindings[:object].window_schedule_repairs.map do |wrs|
                bindings[:view].content_tag(:div, style: 'margin: 10px 0; padding: 10px; background-color: #f9fafb; border-radius: 6px;') do
                  bindings[:view].link_to(
                    "#{wrs.name} (#{wrs.reference_number})",
                    bindings[:view].rails_admin.show_path(model_name: 'window_schedule_repair', id: wrs.id),
                    style: 'text-decoration: none; color: #000000; font-weight: 500;'
                  ) +
                  bindings[:view].content_tag(:div, style: 'margin-top: 5px; font-size: 0.875rem;') do
                    status_badge = if wrs.is_archived
                      bindings[:view].content_tag(:span, 'Archived', class: 'badge bg-dark')
                    elsif wrs.is_draft
                      bindings[:view].content_tag(:span, 'Draft', class: 'badge bg-secondary')
                    else
                      status = wrs.status || 'pending'
                      status_class = case status
                      when 'pending'
                        'badge bg-warning text-dark'
                      when 'approved'
                        'badge bg-success'
                      when 'rejected'
                        'badge bg-danger'
                      when 'completed'
                        'badge bg-info'
                      else
                        'badge bg-secondary'
                      end
                      bindings[:view].content_tag(:span, status.titleize, class: status_class)
                    end
                    "Flat: #{wrs.flat_number || 'N/A'} | Status: ".html_safe + status_badge
                  end
                end
              end.join.html_safe
            end
          else
            'No WRS found'
          end
        end
      end
      field :created_at
      field :updated_at
      field :deleted_at
    end

    edit do
      field :name
      field :street
      field :city
      field :zipcode
      field :country
    end

    create do
      field :name
      field :street
      field :city
      field :zipcode
      field :country
    end

    update do
      field :name
      field :street
      field :city
      field :zipcode
      field :country
    end
  end

end
