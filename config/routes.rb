Rails.application.routes.draw do
  devise_for :admins

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  mount_devise_token_auth_for "User", at: "auth", controllers: {
    registrations: "users/registrations"
  }

  namespace :api do
    namespace :v1 do
      resources :window_schedule_repairs do
        member do
          post :send_to_webflow
        end
        resources :windows, only: [:index, :create]
      end

      resources :windows, only: [:show, :update, :destroy]

      resources :users do
        collection do
          get :me
        end
      end

      # Webflow API routes
      # Sites
      get "webflow/sites", to: "webflow#sites"
      get "webflow/sites/:site_id", to: "webflow#site"

      # Collections
      get "webflow/sites/:site_id/collections", to: "webflow#collections"
      get "webflow/sites/:site_id/collections/:collection_id", to: "webflow#collection"
      post "webflow/sites/:site_id/collections", to: "webflow#create_collection"
      patch "webflow/sites/:site_id/collections/:collection_id", to: "webflow#update_collection"
      delete "webflow/sites/:site_id/collections/:collection_id", to: "webflow#delete_collection"

      # Collection Items
      get "webflow/sites/:site_id/collections/:collection_id/items", to: "webflow#items"
      get "webflow/sites/:site_id/collections/:collection_id/items/:item_id", to: "webflow#item"
      post "webflow/sites/:site_id/collections/:collection_id/items", to: "webflow#create_item"
      patch "webflow/sites/:site_id/collections/:collection_id/items/:item_id", to: "webflow#update_item"
      delete "webflow/sites/:site_id/collections/:collection_id/items/:item_id", to: "webflow#delete_item"
      post "webflow/sites/:site_id/collections/:collection_id/items/publish", to: "webflow#publish_items"
      post "webflow/sites/:site_id/collections/:collection_id/items/unpublish", to: "webflow#unpublish_items"

      # Forms
      get "webflow/sites/:site_id/forms", to: "webflow#forms"
      get "webflow/sites/:site_id/forms/:form_id", to: "webflow#form"
      post "webflow/sites/:site_id/forms/:form_id/submissions", to: "webflow#create_form_submission"

      # Assets
      get "webflow/sites/:site_id/assets", to: "webflow#assets"
      get "webflow/sites/:site_id/assets/:asset_id", to: "webflow#asset"
      post "webflow/sites/:site_id/assets", to: "webflow#create_asset"
      patch "webflow/sites/:site_id/assets/:asset_id", to: "webflow#update_asset"
      delete "webflow/sites/:site_id/assets/:asset_id", to: "webflow#delete_asset"

      # Users
      get "webflow/sites/:site_id/users", to: "webflow#users"
      get "webflow/sites/:site_id/users/:user_id", to: "webflow#user"
      post "webflow/sites/:site_id/users", to: "webflow#create_user"
      patch "webflow/sites/:site_id/users/:user_id", to: "webflow#update_user"
      delete "webflow/sites/:site_id/users/:user_id", to: "webflow#delete_user"

      # Comments
      get "webflow/sites/:site_id/comments", to: "webflow#comments"
      get "webflow/sites/:site_id/comments/:comment_id", to: "webflow#comment"
      post "webflow/sites/:site_id/comments", to: "webflow#create_comment"
      patch "webflow/sites/:site_id/comments/:comment_id", to: "webflow#update_comment"
      delete "webflow/sites/:site_id/comments/:comment_id", to: "webflow#delete_comment"
    end
  end
end
