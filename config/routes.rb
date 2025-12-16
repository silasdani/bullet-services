Rails.application.routes.draw do
  root "website#home"

  # Public website pages
  get "/about", to: "website#about", as: :about
  post "/contact", to: "website#contact_submit", as: :contact_submit
  get "/wrs/:slug", to: "website#wrs_show", as: :wrs_show
  post "/wrs/:slug/decision", to: "website#wrs_decision", as: :wrs_decision

  # Admin panel (authentication handled in RailsAdmin initializer)
  mount RailsAdmin::Engine => "/admin", as: "rails_admin"

  # HTML Devise routes for admin/superadmin browser login (keep default helpers like new_user_session_path)
  devise_for :users, controllers: {
    sessions: "users/sessions",
    passwords: "users/passwords",
    confirmations: "users/confirmations",
    unlocks: "users/unlocks"
  }

  # Redirect accidental GETs on token auth sign-in to Devise HTML sign-in
  devise_scope :user do
    get "/auth/sign_in", to: redirect("/users/sign_in")
  end

  # Token auth routes (rename route helpers to avoid collisions with Devise)
  mount_devise_token_auth_for "User", at: "auth", as: "api_auth", controllers: {
    registrations: "users/registrations"
  }

  # FreshBooks OAuth callback (for capturing authorization code)
  get '/freshbooks/callback', to: 'freshbooks_callback#callback', as: :freshbooks_callback

  namespace :api do
    namespace :v1 do
      # Webflow webhooks (no authentication required)
      post "webhooks/webflow/collection_item_published", to: "webhooks#webflow_collection_item_published"

      # FreshBooks webhooks (no authentication required, signature verified)
      post "webhooks/freshbooks", to: "freshbooks_webhooks#create"

      # FreshBooks management endpoints
      get "freshbooks/status", to: "freshbooks#status"
      post "freshbooks/sync_clients", to: "freshbooks#sync_clients"
      post "freshbooks/sync_invoices", to: "freshbooks#sync_invoices"
      post "freshbooks/sync_payments", to: "freshbooks#sync_payments"
      post "freshbooks/create_invoice", to: "freshbooks#create_invoice"

      resources :window_schedule_repairs do
        member do
          post :send_to_webflow
          post :restore
          post :publish_to_webflow
          post :unpublish_from_webflow
        end
        resources :windows, only: [ :index, :create ]
      end

      resources :windows, only: [ :show, :update, :destroy ]

      # Image upload routes
      resources :images, only: [] do
        collection do
          post :upload_window_image
          post :upload_window_image_for_wrs
          post :upload_multiple_images
        end
      end

      resources :users do
        collection do
          get :me
        end
      end

      resources :invoices do
        collection do
          post :csv_import
        end
        member do
          post :action
        end
      end

      resources :buildings do
        member do
          get :window_schedule_repairs
        end
      end
    end
  end
end
