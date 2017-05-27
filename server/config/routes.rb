Rails.application.routes.draw do
  root 'dashboard#index'
  resources :values, only: [:create]
end
