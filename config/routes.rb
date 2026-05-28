Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

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
      patch "inventory/:id", to: "inventory#update"
      get "inventory/products/:product_id/kardex", to: "inventory#product_kardex"
      get "inventory/warehouses/:warehouse_id/history", to: "inventory#warehouse_history"
      resources :stock_movements, only: [ :index, :create ]
      post "stock_movements/transfer", to: "stock_movements#transfer"
      post "cash_sessions/open", to: "cash_sessions#open"
      post "cash_sessions/:id/close", to: "cash_sessions#close"
      resources :stores
      resources :branches
      resources :users
      resources :roles
      resources :permissions, only: [ :index ]
      resources :categories
      resources :units
      resources :brands
      resources :payment_methods
      resources :products
      resources :warehouses
      resources :customers
      resources :suppliers
      resources :sales, only: [ :index, :show, :create ] do
        post :void, on: :member
      end
      resources :purchases, only: [ :create ]
      post "mobile/scan_product", to: "mobile#scan_product"
      get "reports/daily_sales", to: "reports#daily_sales"
      get "reports/sales", to: "reports#sales"
      get "reports/sales_by_cashier", to: "reports#sales_by_cashier"
      get "reports/top_products", to: "reports#top_products"
      get "reports/gross_margin", to: "reports#gross_margin"
      get "reports/low_stock", to: "reports#low_stock"
      get "reports/kardex", to: "reports#kardex"
    end
  end
end
