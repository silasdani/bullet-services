Rails.application.routes.draw do
  root 'application#index'

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :admins, skip: [:registrations]
  mount_devise_token_auth_for "User", at: "auth", controllers: {
    registrations: "users/registrations"
  }

  # Add ActiveStorage routes for file serving
  mount ActiveStorage::Engine => "/active_storage"

  namespace :api do
    namespace :v1 do
      resources :window_schedule_repairs do
        member do
          post :send_to_webflow
        end
        resources :windows, only: [:index, :create]
      end

      resources :windows, only: [:show, :update, :destroy]

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

      # Webflow API routes

      # Collections
      get "webflow/collections", to: "webflow#collections"
      get "webflow/collections/:collection_id", to: "webflow#collection"

      # Collection Items
      get "webflow/collections/:collection_id/items", to: "webflow#items"
      get "webflow/collections/:collection_id/items/:item_id", to: "webflow#item"
      post "webflow/collections/:collection_id/items", to: "webflow#create_item"
      patch "webflow/collections/:collection_id/items/:item_id", to: "webflow#update_item"
      delete "webflow/collections/:collection_id/items/:item_id", to: "webflow#delete_item"
      post "webflow/collections/:collection_id/items/publish", to: "webflow#publish_items"
      post "webflow/collections/:collection_id/items/unpublish", to: "webflow#unpublish_items"
    end
  end
end
