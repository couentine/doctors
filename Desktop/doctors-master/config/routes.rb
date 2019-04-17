Rails.application.routes.draw do
  devise_for :users
  resources :docs
  get 'welcome/index'

root 'docs#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
