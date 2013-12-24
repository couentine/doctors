BadgeList::Application.routes.draw do
  devise_for :users

  root :to => 'home#show'

  match 'groups/:id/join' => 'groups#join', via: :post, as: :join_group
  match 'groups/:id/leave' => 'groups#leave', via: :delete, as: :leave_group
  match 'groups/:id/members/:user_id' => 'groups#destroy_user', 
        via: :delete, as: :destroy_group_member, defaults: { type: 'member' }
  match 'groups/:id/admins/:user_id' => 'groups#destroy_user', 
        via: :delete, as: :destroy_group_admin, defaults: { type: 'admin' }
  match 'groups/:id/invited_members/:email/invitation' => 'groups#send_invitation', 
        via: :post, as: :send_group_member_invitation,
        defaults: { type: 'member' },
        constraints: { :email => /[^\/]+/ }
  match 'groups/:id/invited_admins/:email/invitation' => 'groups#send_invitation', 
        via: :post, as: :send_group_admin_invitation,
        defaults: { type: 'admin' },
        constraints: { :email => /[^\/]+/ }
  match 'groups/:id/invited_members/:email' => 'groups#destroy_invited_user', 
        via: :delete, as: :destroy_group_invited_member,
        defaults: { type: 'member' },
        constraints: { :email => /[^\/]+/ }
  match 'groups/:id/invited_admins/:email' => 'groups#destroy_invited_user', 
        via: :delete, as: :destroy_group_invited_admin,
        defaults: { type: 'admin' },
        constraints: { :email => /[^\/]+/ }
  match 'groups/:id/members/add' => 'groups#add_users', via: :get,
        as: :add_group_members, defaults: { type: 'member' }
  match 'groups/:id/admins/add' => 'groups#add_users', via: :get,
        as: :add_group_admins, defaults: { type: 'admin' }
  match 'groups/:id/members' => 'groups#create_users', via: :post,
        as: :create_group_members, defaults: { type: 'member' }
  match 'groups/:id/admins' => 'groups#create_users', via: :post,
        as: :create_group_admins, defaults: { type: 'admin' }

  resources :users, :only => [:show], path: "u"

  match ':id/edit' => 'groups#edit', via: :get
  resources :groups, only: [:index, :new, :create]
  resources :groups, path: "", except: [:index, :new, :create] do
    resources :badges, only: [:index, :new, :create]
    resources :badges, path: "", except: [:index, :new, :create]
  end


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
