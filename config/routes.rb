Rails.application.routes.draw do
  mount_devise_token_auth_for "User", at: "auth", controllers: {
    registrations: "users/registrations"
  }

  namespace :api do
    namespace :v1 do
      resources :quotations do
        member do
          post :send_to_webflow
        end
      end

      resources :users do
        collection do
          get :me
        end
      end

      # Webflow API routes
      namespace :webflow do
        # Sites
        get "sites", to: "webflow#sites"
        get "sites/:site_id", to: "webflow#site"

        # Collections
        get "sites/:site_id/collections", to: "webflow#collections"
        get "sites/:site_id/collections/:collection_id", to: "webflow#collection"
        post "sites/:site_id/collections", to: "webflow#create_collection"
        patch "sites/:site_id/collections/:collection_id", to: "webflow#update_collection"
        delete "sites/:site_id/collections/:collection_id", to: "webflow#delete_collection"

        # Collection Items
        get "sites/:site_id/collections/:collection_id/items", to: "webflow#items"
        get "sites/:site_id/collections/:collection_id/items/:item_id", to: "webflow#item"
        post "sites/:site_id/collections/:collection_id/items", to: "webflow#create_item"
        patch "sites/:site_id/collections/:collection_id/items/:item_id", to: "webflow#update_item"
        delete "sites/:site_id/collections/:collection_id/items/:item_id", to: "webflow#delete_item"
        post "sites/:site_id/collections/:collection_id/items/publish", to: "webflow#publish_items"
        post "sites/:site_id/collections/:collection_id/items/unpublish", to: "webflow#unpublish_items"

        # Forms
        get "sites/:site_id/forms", to: "webflow#forms"
        get "sites/:site_id/forms/:form_id", to: "webflow#form"
        post "sites/:site_id/forms/:form_id/submissions", to: "webflow#create_form_submission"

        # Assets
        get "sites/:site_id/assets", to: "webflow#assets"
        get "sites/:site_id/assets/:asset_id", to: "webflow#asset"
        post "sites/:site_id/assets", to: "webflow#create_asset"
        patch "sites/:site_id/assets/:asset_id", to: "webflow#update_asset"
        delete "sites/:site_id/assets/:asset_id", to: "webflow#delete_asset"

        # Users
        get "sites/:site_id/users", to: "webflow#users"
        get "sites/:site_id/users/:user_id", to: "webflow#user"
        post "sites/:site_id/users", to: "webflow#create_user"
        patch "sites/:site_id/users/:user_id", to: "webflow#update_user"
        delete "sites/:site_id/users/:user_id", to: "webflow#delete_user"

        # Comments
        get "sites/:site_id/comments", to: "webflow#comments"
        get "sites/:site_id/comments/:comment_id", to: "webflow#comment"
        post "sites/:site_id/comments", to: "webflow#create_comment"
        patch "sites/:site_id/comments/:comment_id", to: "webflow#update_comment"
        delete "sites/:site_id/comments/:comment_id", to: "webflow#delete_comment"
      end
    end
  end
end
