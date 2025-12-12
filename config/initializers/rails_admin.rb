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
    void_invoice_with_email
    apply_discount
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

    # Optimize queries by eager loading associations
    scope { Invoice.includes(:freshbooks_invoices) }

    list do
      # Name
      field :name do
        label 'Name'
      end

      # PDF
      field :invoice_pdf_link do
        label 'PDF'
        pretty_value do
          if value.present?
          bindings[:view].link_to(
            bindings[:view].content_tag(:i, '', class: 'fas fa-file-pdf me-1') + 'View PDF',
            value,
            target: '_blank',
            class: 'btn btn-sm btn-outline-primary',
            style: 'text-decoration: none;'
          )
          else
            bindings[:view].content_tag(:span, 'No PDF', class: 'text-muted')
          end
        end
      end

      # ClientID
      field :freshbooks_client_id do
        label 'Client ID'
      end

      # Generated by (created date)
      field :created_at do
        label 'Generated by'
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

      # Status
      field :status do
        label 'Status'
        pretty_value do
          invoice = bindings[:object]
          status = invoice.status || invoice.final_status || 'draft'
          status_class = case status.downcase
          when 'paid'
            'badge bg-success'
          when 'sent', 'viewed'
            'badge bg-info'
          when 'draft'
            'badge bg-secondary'
          when 'voided'
            'badge bg-danger'
          when 'overdue'
            'badge bg-warning text-dark'
          else
            'badge bg-primary'
          end
          bindings[:view].content_tag(:span, status.titleize, class: status_class)
        end
      end

      # Amount
      field :total_amount do
        label 'Amount'
        pretty_value do
          invoice = bindings[:object]
          amount = invoice.total_amount
          if amount && amount > 0
            bindings[:view].content_tag(:span, "£#{amount.round(2)}", class: 'fw-semibold')
          else
            bindings[:view].content_tag(:span, '-', class: 'text-muted')
          end
        end
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

          # Add JavaScript to fix dropdown positioning using fixed positioning
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

                      // Use Bootstrap's dropdown events instead of click
                      dropdown.addEventListener('show.bs.dropdown', function(e) {
                        // Calculate position before dropdown is shown
                        var rect = button.getBoundingClientRect();
                        var menuHeight = menu.offsetHeight || 200;
                        var viewportHeight = window.innerHeight;
                        var spaceBelow = viewportHeight - rect.bottom;
                        var spaceAbove = rect.top;

                        // Prepare menu for fixed positioning
                        menu.style.position = 'fixed';
                        menu.style.zIndex = '99999';
                        menu.style.visibility = 'visible';
                        menu.style.opacity = '1';

                        // Position above if not enough space below
                        if (spaceBelow < menuHeight && spaceAbove > menuHeight) {
                          menu.style.top = (rect.top - menuHeight - 8) + 'px';
                          menu.style.bottom = 'auto';
                          menu.style.left = rect.left + 'px';
                          menu.style.right = 'auto';
                          menu.style.marginTop = '0';
                          menu.style.marginBottom = '0';
                        } else {
                          menu.style.top = (rect.bottom + 8) + 'px';
                          menu.style.bottom = 'auto';
                          menu.style.left = rect.left + 'px';
                          menu.style.right = 'auto';
                          menu.style.marginTop = '0';
                          menu.style.marginBottom = '0';
                        }
                      });

                      // Ensure menu is visible after Bootstrap shows it
                      dropdown.addEventListener('shown.bs.dropdown', function(e) {
                        var rect = button.getBoundingClientRect();
                        var menuHeight = menu.offsetHeight || 200;
                        var viewportHeight = window.innerHeight;
                        var spaceBelow = viewportHeight - rect.bottom;
                        var spaceAbove = rect.top;

                        // Force fixed positioning and visibility
                        menu.style.position = 'fixed';
                        menu.style.zIndex = '99999';
                        menu.style.display = 'block';
                        menu.style.visibility = 'visible';
                        menu.style.opacity = '1';

                        // Recalculate position in case menu size changed
                        if (spaceBelow < menuHeight && spaceAbove > menuHeight) {
                          menu.style.top = (rect.top - menuHeight - 8) + 'px';
                          menu.style.bottom = 'auto';
                        } else {
                          menu.style.top = (rect.bottom + 8) + 'px';
                          menu.style.bottom = 'auto';
                        }
                        menu.style.left = rect.left + 'px';
                        menu.style.right = 'auto';
                      });
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
