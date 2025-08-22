Rails.application.routes.draw do
  root 'application#index'

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :admins, skip: [:registrations]
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
