BadgeList::Application.routes.draw do
  require 'sidekiq/web'

  resources :tags

  resources :entries

  devise_for :users, :controllers => { registrations: 'registrations', sessions: 'sessions',
    omniauth_callbacks: 'users/omniauth_callbacks' }
  devise_scope :user do
    get 'users/logout', to: 'devise/sessions#destroy' # custom path for polymer pages (they can't fake the delete method as easily)
  end

  root :to => 'home#root'
  resources :users, :only => [:show], path: 'u'
  match 'i' => 'badge_maker#show', via: :get, as: :badge_image
  match 'j/image_key' => 'static_pages#image_key', via: :get, as: :image_key
  match 'w' => 'home#root_external', via: :get, as: :root_external
  match 'home' => 'home#root_internal', via: :get, as: :root_internal
  match 'pricing' => 'home#pricing', via: :get, as: :pricing
  match 'pricing-k12' => 'home#pricing_k12', via: :get, as: :pricing_k12
  match 'how-it-works' => 'home#how_it_works', via: :get, as: :how_it_works
  match 'privacy-policy' => 'home#privacy_policy', via: :get, as: :privacy_policy
  match 'terms-of-service' => 'home#terms_of_service', via: :get, as: :terms_of_service

  # === ADMIN PATHS === #
  scope '/a' do
    resources :users, :only => [:index, :edit, :new, :create, :update]
    resources :info_items, :only => [:index, :show]
  end
  match 'a/groups' => 'groups#index', via: :get, as: :group_index
  match 'a/metrics' => 'admin_pages#metrics', via: :get, as: :admin_metrics
  match 'a/icons' => 'admin_pages#icons', via: :get, as: :icon_list
  match 'a' => 'admin_pages#index', via: :get
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/a/sidekiq'
  end

  # === API PATHS === #
  namespace :api do
    namespace :v1 do
      resources :pollers, only: [:show]

      resources :users, only: [:show] do
        resources :groups, only: [:index]
        resources :portfolios, only: [:index]
        
        resources :app_user_memberships, only: [:index, :create, :show]
        resources :authentication_tokens, only: [:index, :create]
        
        match ':email/portfolios' => 'portfolios#index', constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :get
        match ':email/groups' => 'groups#index', constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :get
        match ':email/app_user_memberships' => 'app_user_memberships#index', 
          constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :get
        match ':email/app_user_memberships' => 'app_user_memberships#create',
          constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :post
        match ':email/apps' => 'apps#index', constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :get
        match ':email/authentication_tokens' => 'authentication_tokens#index', 
          constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :get
        match ':email' => 'users#show', constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :get
      end
      resources :authentication_tokens, only: [:index, :update, :show, :destroy]

      resources :groups, only: [:index, :show] do
        resources :badges, only: [:index, :show]
        resources :users, only: [:index]
        
        resources :app_group_memberships, only: [:index, :create]
      end
      
      resources :badges, only: [:index, :show] do
        resources :portfolios, only: [:index, :show] do
          match ':email' => 'portfolios#show', constraints: { :email => /.+@.+\..*/ }, on: :collection, via: :get
        end
        resources :endorsements, only: [:create]
      end
      resources :portfolios, only: [:show]

      resources :apps, only: [:create, :update, :show, :destroy] do
        resources :app_user_memberships, only: [:index, :create]
        resources :app_group_memberships, only: [:index, :create]
      end
      resources :app_user_memberships, only: [:index, :update, :show, :destroy]
      resources :app_group_memberships, only: [:update, :show, :destroy]
    end
  end

  namespace :docs do
    root to: 'doc_pages#index'

    namespace :api do
      namespace :v1 do
        root to: 'external_api_docs#show_html'
        match 'internal' => 'internal_api_docs#show_html', via: :get

        match 'swagger.json' => 'external_api_docs#show_json', via: :get, as: :external_json
        match 'openapi.json' => 'external_api_docs#show_json', via: :get
        match 'internal_api.json' => 'internal_api_docs#show_json', via: :get, as: :internal_json
      end
    end
  end
  
  # === CMS LANDING PAGE PATHS === #

  match '/for/:id' => 'home#landing_pages', via: :get
  match '/customers/:id' => 'home#landing_pages', via: :get
  match '/features/:id' => 'home#landing_pages', via: :get

  # === INFO PATHS === #
  scope '/i' do
    resources :subscription_plans, only: [:index]
    resources :subscription_features, only: [:index]
  end

  # === WEBHOOK PATHS === #
  match 'h/lti/launch' => 'lti#launch', via: :post, as: :lti_launch
  match 'h/lti/config' => 'lti#config_xml', via: :get, as: :lti_config
  match 'h/stripe_event' => 'webhooks#stripe_event', via: :post
  match 'h/postmark_bounce' => 'webhooks#postmark_bounce', via: :post

  # === POLLER PATHS === #
  match 'pollers/:id' => 'pollers#show', via: :get, as: :poller
  
  # === RESTFUL PATHS TO PRELOAD === #
  resources :domains
  resources :report_results, :only => [:index, :show, :new, :create]

  # === MANUAL USER PATHS === #
  match 'users/cards' => 'users#add_card', via: :post, as: :add_card
  match 'users/cards' => 'users#refresh_cards', via: :get, as: :refresh_cards
  match 'users/card/:id' => 'users#delete_card', via: :delete, as: :delete_card
  match 'users/payments' => 'users#payment_history', via: :get, as: :payment_history
  match 'u/:id/new_password' => 'users#new_password', via: :post, as: :user_new_password
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
  match ':group_id/invited_users' => 'groups#invited_users',via: :get, as: :group_invited_users
  match ':group_id/lti_keys/:consumer_key' => 'groups#destroy_lti_key', via: :delete, 
    as: :group_lti_key
  match ':group_id/lti_keys' => 'groups#create_lti_key', via: :post, as: :create_group_lti_key
  match ':group_id/lti_contexts/:context_id' => 'groups#update_lti_context',via: :put,
    as: :group_lti_context
  match ':group_id/lti_contexts/:context_id' => 'groups#destroy_lti_context', via: :delete
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

  # These should eventually be moved to their own RESTfull controllers         
  match ':group_id/users' => 'groups#users', via: :get, as: :group_users
  match ':group_id/badges' => 'groups#badges', via: :get, as: :group_badges
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
  match ':group_id/:badge_id/endorsements/add' => 'badges#add_endorsements_form', via: :get, as: :add_endorsements_form

  # === MANUAL LOG PATHS === #
  match ':group_id/:badge_id/o/:id' => 'logs#show', via: :get, as: :open_badge_assertion,
    defaults: { f: 'ob1' }
  match ':group_id/:badge_id/u/:id/retract' => 'logs#retract', via: :post, as: :log_retract
  match ':group_id/:badge_id/u/:id/unretract' => 'logs#unretract', via: :post, as: :log_unretract

  # === MANUAL TAG PATHS === #
  match ':group_id/:badge_id/:tag_id/restore' => 'tags#restore', via: :post, as: :tag_restore

  # === APP ROUTES === #
  resources :apps, only: [:show]

  # === NESTED RESOURCE PATHS FOR GROUP, BADGE, LOG & ENTRY === #
  match ':id/edit' => 'groups#edit', via: :get
  match ':group_id/:id/edit' => 'badges#edit', via: :get
  resources :groups, only: [:new, :create]
  resources :groups, path: '', except: [:index] do
    resources :badges, only: [:new, :create]
    resources :group_tags, except: [:new, :edit], path: 'tags', as: 'tags' do
      resources :group_tag_users, path: 'users', as: 'users', only: [:index, :destroy] do
        collection do
          get 'add'
          post 'bulk_create'
        end
      end
      resources :group_tag_badges, path: 'badges', as: 'badges', only: [:index, :destroy] do
        collection do
          get 'add'
          post 'bulk_create'
        end
      end
    end
    resources :badges, path: '', except: [:index, :new, :create] do
      match 'join' => 'logs#create', via: :get
      resources :logs, only: [:create]
      resources :logs, path: 'u', except: [:index, :new, :create] do
        resources :entries, only: [:new, :create]
        resources :entries, path: '', except: [:index, :new, :create]
      end

      resources :tags, path: '', except: [:index, :new, :create]
    end
  end
  
end
