Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth'

  namespace :api do
    namespace :v1 do
      resources :quotations do
        member do
          post :send_to_webflow
        end
      end

      resources :users, only: [:index, :show, :update] do
        member do
          patch :update_role
        end
      end
    end
  end
end
