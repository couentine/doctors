BadgeList::Application.routes.draw do

  resources :tags


  resources :entries


  devise_for :users

  root :to => 'home#show'
  resources :users, :only => [:show], path: "u"
  match 'i' => 'badge_maker#show', via: :get, as: :badge_image
  match 'c' => 'static_pages#colors', via: :get

  # === ADMIN PATHS === #
  scope '/a' do
    resources :users, :only => [:index]
  end
  match 'a' => 'admin_pages#index', via: :get

  # === MANUAL GROUP PATHS === #
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
  match ':group_id/:badge_id/topics' => 'tags#index', via: :get, as: :badge_topics
  match ':group_id/:badge_id/issue' => 'badges#issue_form', via: :get, as: :badge_issue
  match ':group_id/:badge_id/issue' => 'badges#issue_save', via: :post

  # === NESTED RESOURCE PATHS FOR GROUP, BADGE, LOG & ENTRY === #
  match ':id/edit' => 'groups#edit', via: :get
  match ':group_id/:id/edit' => 'badges#edit', via: :get
  resources :groups, only: [:new, :create]
  resources :groups, path: "", except: [:index, :new, :create] do
    resources :badges, only: [:new, :create]
    resources :badges, path: "", except: [:index, :new, :create] do
      resources :logs, only: [:create]
      resources :logs, path: "u", except: [:index, :new, :create] do
        resources :entries, only: [:new, :create]
        resources :entries, path: "", except: [:index, :new, :create]
      end

      resources :tags, path: "", except: [:index, :new, :create]
    end
  end
  
end
