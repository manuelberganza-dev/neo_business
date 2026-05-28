Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      devise_for :users, skip: :all

      devise_scope :user do
        post "auth/login", to: "auth/sessions#create", as: :user_session, defaults: { format: :json }
        delete "auth/logout", to: "auth/sessions#destroy", as: :destroy_user_session, defaults: { format: :json }
      end

      get "me", to: "profile#show"
    end
  end
end
