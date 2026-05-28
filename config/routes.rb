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

      get "inventory", to: "inventory#index"
      resources :stock_movements, only: [ :index, :create ]
      post "cash_sessions/open", to: "cash_sessions#open"
      post "cash_sessions/:id/close", to: "cash_sessions#close"
      resources :sales, only: [ :index, :show, :create ] do
        post :void, on: :member
      end
      resources :purchases, only: [ :create ]
      post "mobile/scan_product", to: "mobile#scan_product"
      get "reports/daily_sales", to: "reports#daily_sales"
      get "reports/low_stock", to: "reports#low_stock"
    end
  end
end
