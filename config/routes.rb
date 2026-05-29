Rails.application.routes.draw do
  get "/up", to: "platform#live"
  get "/ready", to: "platform#ready"
  get "/metrics", to: "platform#metrics"

  namespace :v1 do
    resources :organizations, only: :create
    get "/organization", to: "organizations#show"
    resources :memberships, only: %i[index create update]
    resources :tickets, only: %i[index create show update]
  end
end
