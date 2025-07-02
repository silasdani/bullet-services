Rails.application.routes.draw do
  mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    registrations: 'users/registrations'
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
    end
  end
end
