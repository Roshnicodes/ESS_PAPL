Rails.application.routes.draw do
  devise_for :users, skip: %i[registrations passwords]

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end
  devise_scope :user do
    root "devise/sessions#new"
  end

  # Tour Plan / Tour History  (?type=local => Local Mileage Claim / History)
  resources :tours, only: %i[index new create show edit update destroy] do
    member do
      patch :cancel
      patch :submit
    end
    resource :claim, controller: "tour_claims", only: %i[new create edit update show]
  end

  # Local Mileage Claim menu – B. Local Travel form directly (as on live ESS)
  resource :local_mileage, only: %i[new create]

  namespace :approvals do
    resources :tours, only: %i[index show] do
      get :done, on: :collection   # tours I have already acted on
      member do
        patch :approve
        patch :send_back, path: "return"
        patch :reject
      end
    end
    resources :claims, only: %i[index show update] do
      member do
        patch :forward
        patch :approve
        patch :send_back, path: "return"
        patch :reply
        patch :reject
      end
    end
  end

  resources :notifications, only: %i[index show] do
    patch :mark_all_read, on: :collection
    patch "read_for_tour/:tour_id", on: :collection, action: :read_for_tour, as: :read_for_tour
  end

  # IT Tools – open Guest House / Help Desk / Training / GeoHub already signed in
  get "it-tools/:tool", to: "it_tools#open", as: :it_tool, constraints: { tool: /guest_house|help_desk|training|geohub|old_ess/ }

  namespace :account do
    resource :password, only: %i[edit update]
    resources :bank_accounts, only: %i[index new create edit update] do
      member do
        patch :toggle
        patch :make_primary
        get   :passbook
      end
    end
  end

  namespace :masters do
    resource :it_tool_settings, only: %i[show update], path: "it-tool-settings"
    resources :cities, only: %i[index new create edit update] do
      patch :toggle, on: :member
      collection do
        get  :export
        post :import
      end
    end
    resources :travel_modes, only: %i[index new create edit update] do
      patch :toggle, on: :member
    end
    resources :mileage_rates, only: %i[index create]
    resources :all_tours, only: :index
    resources :finance_codes, only: :index do
      collection do
        post :import
        get :template
      end
    end
    resources :claim_cutoff_rules, only: %i[index new create edit update destroy]
    resources :users, only: %i[index new create edit update] do
      collection do
        get  :export
        post :import
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
