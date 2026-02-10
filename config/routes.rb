Rails.application.routes.draw do
  root "website#home"

  # Public website pages
  get "/about", to: "website#about", as: :about
  get "/services", to: "website#services", as: :services
  get "/terms", to: "website#terms", as: :terms
  get "/terms/wrs", to: "website#wrs_terms", as: :wrs_terms
  post "/contact", to: "website#contact_submit", as: :contact_submit
  get "/wrs/:slug", to: "website#wrs_show", as: :wrs_show
  post "/wrs/:slug/decision", to: "website#wrs_decision", as: :wrs_decision

  # HTML Devise routes for admin/superadmin browser login (keep default helpers like new_user_session_path)
  devise_for :users, controllers: {
    sessions: "users/sessions",
    passwords: "users/passwords",
    confirmations: "users/confirmations",
    unlocks: "users/unlocks"
  }

  # Admin panel - Avo (mounted after Devise routes to ensure route helpers are available)
  # Custom dashboard route must be before the mount so /avo/dashboard is handled by the app
  get "#{Avo.configuration.root_path}/dashboard", to: "avo/dashboard#index", as: :avo_dashboard

  mount Avo::Engine, at: Avo.configuration.root_path

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
          post :restore
          post :check_in
          post :check_out
        end
        resources :windows, only: [ :index, :create ]
        resources :ongoing_works, only: [ :index, :create ]
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
          post :register_fcm_token
        end
        member do
          post :block
          post :unblock
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
          post :assign
          post :unassign
        end
      end

      resources :work_sessions, only: [ :index, :show ] do
        collection do
          get :active
        end
      end
      resources :ongoing_works, only: [ :show, :update, :destroy ]
      resources :timesheets, only: [ :index ] do
        collection do
          get :export
        end
      end
      resources :notifications, only: [ :index, :show ] do
        member do
          post :mark_read
          post :mark_unread
        end
        collection do
          post :mark_all_read
        end
      end

      resource :dashboard, only: [ :show ]
    end
  end
end
