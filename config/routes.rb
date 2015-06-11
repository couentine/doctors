BadgeList::Application.routes.draw do
  require 'sidekiq/web'

  resources :tags


  resources :entries


  devise_for :users

  root :to => 'home#root'
  resources :users, :only => [:show], path: "u"
  match 'i' => 'badge_maker#show', via: :get, as: :badge_image
  match 'c' => 'static_pages#colors', via: :get
  match 'w' => 'home#root_external', via: :get, as: :root_external
  match 'pricing' => 'home#pricing', via: :get, as: :pricing
  match 'pricing-k12' => 'home#pricing_k12', via: :get, as: :pricing_k12
  match 'privacy-policy' => 'home#privacy_policy', via: :get, as: :privacy_policy
  match 'terms-of-service' => 'home#terms_of_service', via: :get, as: :terms_of_service

  # === ADMIN PATHS === #
  scope '/a' do
    resources :users, :only => [:index]
    resources :info_items, :only => [:index, :show]
  end
  match 'a' => 'admin_pages#index', via: :get
  match 'a/groups' => 'groups#index', via: :get
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/a/sidekiq'
  end
  
  # === WEBHOOK PATHS === #
  match 'h/stripe_event' => 'webhooks#stripe_event', via: :post

  # === POLLER PATHS === #
  match 'p/:id' => 'pollers#show', via: :get, as: :poller
  
  # === MANUAL FORM PATHS === #
  match 'f/talk-with-us' => 'forms#user_discussion', via: :post
  # match 'f/contact-us' => 'forms#contact_us', via: :post

  # === MANUAL USER PATHS === #
  match 'users/cards' => 'users#add_card', via: :post, as: :add_card
  match 'users/cards' => 'users#refresh_cards', via: :get, as: :refresh_cards
  match 'users/card/:id' => 'users#delete_card', via: :delete, as: :delete_card
  match 'users/payments' => 'users#payment_history', via: :get, as: :payment_history

  # === MANUAL GROUP PATHS === #
  match ':group_id/cancel' => 'groups#cancel_subscription', via: :post, as: :cancel_subscription
  match ':group_id/join' => 'groups#join', via: :post, as: :join_group
  match ':group_id/leave' => 'groups#leave', via: :delete, as: :leave_group
  match ':group_id/members/:user_id' => 'groups#destroy_user', 
        via: :delete, as: :destroy_group_member, defaults: { type: 'member' }
  match ':group_id/admins/:user_id' => 'groups#destroy_user', 
        via: :delete, as: :destroy_group_admin, defaults: { type: 'admin' }
  match ':group_id/invited_members/:email/invitation' => 'groups#send_invitation', 
        via: :post, as: :send_group_member_invitation,
        defaults: { type: 'member' },
        constraints: { :email => /[^\/]+/ }
  match ':group_id/invited_admins/:email/invitation' => 'groups#send_invitation', 
        via: :post, as: :send_group_admin_invitation,
        defaults: { type: 'admin' },
        constraints: { :email => /[^\/]+/ }
  match ':group_id/invited_members/:email' => 'groups#destroy_invited_user', 
        via: :delete, as: :destroy_group_invited_member,
        defaults: { type: 'member' },
        constraints: { :email => /[^\/]+/ }
  match ':group_id/invited_admins/:email' => 'groups#destroy_invited_user', 
        via: :delete, as: :destroy_group_invited_admin,
        defaults: { type: 'admin' },
        constraints: { :email => /[^\/]+/ }
  match ':group_id/members/add' => 'groups#add_users', via: :get,
        as: :add_group_members, defaults: { type: 'member' }
  match ':group_id/admins/add' => 'groups#add_users', via: :get,
        as: :add_group_admins, defaults: { type: 'admin' }
  match ':group_id/members' => 'groups#create_users', via: :post,
        as: :create_group_members, defaults: { type: 'member' }
  match ':group_id/admins' => 'groups#create_users', via: :post,
        as: :create_group_admins, defaults: { type: 'admin' }

  # === MANUAL BADGE PATHS === #
  match ':group_id/:badge_id/learners/add' => 'badges#add_learners', via: :get,
        as: :add_badge_learners
  match ':group_id/:badge_id/learners' => 'badges#create_learners', via: :post,
        as: :create_badge_learners
  match ':group_id/:badge_id/entries' => 'badges#entries_index', via: :get, as: :badge_entries
  # match ':group_id/:badge_id/topics' => 'tags#index', via: :get, as: :badge_topics
  match ':group_id/:badge_id/issue' => 'badges#issue_form', via: :get, as: :badge_issue
  match ':group_id/:badge_id/issue' => 'badges#issue_save', via: :post
  

  # === MANUAL LOG PATHS === #
  match ':group_id/:badge_id/o/:id' => 'logs#show', via: :get, as: :open_badge_assertion,
    defaults: { f: 'ob1' }

  # === MANUAL TAG PATHS === #
  match ':group_id/:badge_id/:tag_id/restore' => 'tags#restore', via: :post, as: :tag_restore

  # === NESTED RESOURCE PATHS FOR GROUP, BADGE, LOG & ENTRY === #
  match ':id/edit' => 'groups#edit', via: :get
  match ':group_id/:id/edit' => 'badges#edit', via: :get
  resources :groups, only: [:new, :create]
  resources :groups, path: "", except: [:index, :new, :create] do
    resources :badges, only: [:new, :create]
    resources :badges, path: "", except: [:index, :new, :create] do
      match 'join' => 'logs#create', via: :get
      resources :logs, only: [:create]
      resources :logs, path: "u", except: [:index, :new, :create] do
        resources :entries, only: [:new, :create]
        resources :entries, path: "", except: [:index, :new, :create]
      end

      resources :tags, path: "", except: [:index, :new, :create]
    end
  end
  
end
