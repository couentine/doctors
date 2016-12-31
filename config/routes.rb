BadgeList::Application.routes.draw do
  require 'sidekiq/web'

  resources :tags


  resources :entries


  devise_for :users, :controllers => { registrations: 'registrations', sessions: 'sessions',
    omniauth_callbacks: "users/omniauth_callbacks" }

  root :to => 'home#root'
  resources :users, :only => [:show], path: "u"
  match 'i' => 'badge_maker#show', via: :get, as: :badge_image
  match 'c' => 'static_pages#colors', via: :get
  match 'j/image_key' => 'static_pages#image_key', via: :get, as: :image_key
  match 'w' => 'home#root_external', via: :get, as: :root_external
  match 'pricing' => 'home#pricing', via: :get, as: :pricing
  match 'pricing-k12' => 'home#pricing_k12', via: :get, as: :pricing_k12
  match 'how-it-works' => 'home#how_it_works', via: :get, as: :how_it_works
  match 'privacy-policy' => 'home#privacy_policy', via: :get, as: :privacy_policy
  match 'terms-of-service' => 'home#terms_of_service', via: :get, as: :terms_of_service
  match 'help-staging' => 'home#help', via: :get, as: :help

  # === ADMIN PATHS === #
  scope '/a' do
    resources :users, :only => [:index]
    resources :info_items, :only => [:index, :show]
  end
  match 'a/groups' => 'groups#index', via: :get, as: :group_index
  match 'a' => 'admin_pages#index', via: :get
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/a/sidekiq'
  end
  
  # === WEBHOOK PATHS === #
  match 'h/stripe_event' => 'webhooks#stripe_event', via: :post
  match 'h/postmark_bounce' => 'webhooks#postmark_bounce', via: :post

  # === POLLER PATHS === #
  match 'p/:id' => 'pollers#show', via: :get, as: :poller
  
  # === RESTFUL PATHS TO PRELOAD === #
  resources :domains

  # === MANUAL FORM PATHS === #
  match 'f/talk-with-us' => 'forms#user_discussion', via: :post
  # match 'f/contact-us' => 'forms#contact_us', via: :post

  # === MANUAL USER PATHS === #
  match 'users/cards' => 'users#add_card', via: :post, as: :add_card
  match 'users/cards' => 'users#refresh_cards', via: :get, as: :refresh_cards
  match 'users/card/:id' => 'users#delete_card', via: :delete, as: :delete_card
  match 'users/payments' => 'users#payment_history', via: :get, as: :payment_history
  match 'u/:id/confirm_account' => 'users#confirm_account', via: :post, as: :user_confirm
  match 'u/:id/unblock_email' => 'users#unblock_email', via: :post, as: :user_unblock
  match 'u/:id/update_image' => 'users#update_image', via: :post, as: :user_update_image
  match 'u/:id/add_password' => 'users#add_password', via: :post, as: :user_add_password

  # === MANUAL GROUP PATHS === #
  match ':group_id/cancel' => 'groups#cancel_subscription', via: :post, as: :cancel_subscription
  match ':group_id/join' => 'groups#join', via: :post, as: :join_group
  match ':group_id/join' => 'groups#join', via: :get
  match ':group_id/leave' => 'groups#leave', via: :delete, as: :leave_group
  match ':group_id/settings' => 'groups#update_group_settings', via: :put, as: :group_settings
  match ':group_id/clear_bounce_log' => 'groups#clear_bounce_log',via: :post,as: :clear_bounce_log
  match ':group_id/review' => 'groups#review', via: :get, as: :group_review
  match ':group_id/full_logs' => 'groups#full_logs', via: :get, as: :group_full_logs
  match ':group_id/validations' => 'groups#create_validations', via: :post, as: :group_validations
  match ':group_id/copy_badges' => 'groups#copy_badges_form',via: :get, as: :copy_badges_form
  match ':group_id/copy_badges' => 'groups#copy_badges_action',via: :post, as: :copy_badges_action
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
  match ':group_id/:badge_id/move' => 'badges#move', via: :put

  # === MANUAL LOG PATHS === #
  match ':group_id/:badge_id/o/:id' => 'logs#show', via: :get, as: :open_badge_assertion,
    defaults: { f: 'ob1' }
  match ':group_id/:badge_id/u/:id/retract' => 'logs#retract', via: :post, as: :log_retract
  match ':group_id/:badge_id/u/:id/unretract' => 'logs#unretract', via: :post, as: :log_unretract

  # === MANUAL TAG PATHS === #
  match ':group_id/:badge_id/:tag_id/restore' => 'tags#restore', via: :post, as: :tag_restore

  # === NESTED RESOURCE PATHS FOR GROUP, BADGE, LOG & ENTRY === #
  match ':id/edit' => 'groups#edit', via: :get
  match ':group_id/:id/edit' => 'badges#edit', via: :get
  resources :groups, only: [:new, :create]
  resources :groups, path: "", except: [:index] do
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
