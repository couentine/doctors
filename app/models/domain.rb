class Domain
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONFilter
  include JSONTemplater
  
  # === JSON PARAMS === #

  JSON_FIELDS = [:url, :is_private, :visible_to_domain_urls, :can_see_domain_urls]
  JSON_TEMPLATES = {
    for_user_cache: [:id, :url, :is_private, :visible_to_domain_urls, :can_see_domain_urls, 
      :non_private_domain_user_ids]
  }

  # === RELATIONSHIPS === #

  has_and_belongs_to_many :visible_to_domains, inverse_of: :can_see_domains, class_name: "Domain"
  has_and_belongs_to_many :can_see_domains, inverse_of: :visible_to_domains, class_name: "Domain"
  belongs_to :owner, inverse_of: :owned_domains, class_name: "User"
  has_many :users, inverse_of: :domain, class_name: "User", dependent: :nullify

  # === FIELDS & VALIDATIONS === #

  field :url,                           type: String
  field :is_private,                    type: Boolean, default: false
  field :non_private_domain_user_ids,   type: Array, default: []

  validates :url, presence: true, length: { minimum: 3 }, uniqueness: { case_sensitive: false }

  # === CALLBACK === #

  before_validation :clean_url
  before_save :update_users
  before_destroy :do_unlink_users

  # === MOCK FIELD METHODS === #

  def visible_to_domain_urls; visible_to_domains.map { |domain| domain.url }; end
  def can_see_domain_urls; can_see_domains.map { |domain| domain.url }; end
  def non_private_user_usernames
    users.where(is_non_private_domain_user: true).map { |user| user.username }
  end

  # === CLASS METHODS === #

  # This will update the many to many visible_to_domains relationship to match the passed array of
  # domains. NOTE: It WILL save and queue an update of the user caches.
  def update_visible_to_domains(new_domains)
    # STEP 1 - Remove any which are no longer present
    visible_to_domains.each do |existing_domain|
      if !new_domains.include? existing_domain
        self.visible_to_domains.delete existing_domain
      end
    end
    
    # STEP 2 - Add any missing domains
    new_domains.each do |new_domain|
      if !visible_to_domains.include? new_domain
        self.visible_to_domains << new_domain
      end
    end

    # Now save the record and update the user caches.
    # NOTE: We'll use a longer 30 second wait in order to avoid a collision with the call below
    #(this is messy but this functionality will only be used by admins for now)
    self.save if self.changed?
    Domain.delay_for(30.seconds, queue: 'low').update_user_domain_caches(self.id)
    true
  end

  # === ASYNC CLASS METHODS === #

  # Call this asynchronously to find and link all users with matching email domains
  # Set clear_existing_users to first clear the cache on existing users
  def self.find_and_link_users(domain_id, clear_existing_users = false)
    domain = Domain.find(domain_id) rescue nil

    if domain
      if clear_existing_users
        domain.users.each do |user|
          user.clear_domain_cache
          user.save if user.changed?
        end
      end

      domain_json = domain.json(:for_user_cache)

      # Find all users where email ends with this domain's url
      User.where(email: /^.+@#{domain.url}$/i).each do |user|
        if user.domain != domain
          user.clear_domain_cache
          user.update_domain_cache_from domain_json
          user.save if user.changed?
        end
      end
    end
  end

  # Call this asynchronously to copy cached info to all linked domain users
  # This method will not find new users and it will not clear the domain cache first
  def self.update_user_domain_caches(domain_id)
    domain = Domain.find(domain_id) rescue nil

    if domain
      domain_json = domain.json(:for_user_cache)

      domain.users.each do |user|
        user.update_domain_cache_from domain_json
        user.save if user.changed?
      end
    end
  end

  # Call this asynchronously to clear caches on all passed user ids
  def self.clear_user_caches(user_ids)
    users = User.where(:id.in => user_ids)

    if !users.blank?
      users.each do |user|
        user.clear_domain_cache
        user.save if user.changed?
      end
    end
  end

  # Call to update all users 
  def self.set_non_private_domain_users(domain_id)
    domain = Domain.find(domain_id) rescue nil

    if domain
      domain.users.each do |user|
        user.clear_domain_cache
        user.save if user.changed?
      end
    end
  end

protected

  def clean_url
    self.url = url.downcase.strip unless url.blank?
  end

  def update_users
    if new_record? || url_changed?
      # clear existing users only if this is an update
      Domain.delay_for(5.seconds, queue: 'low').find_and_link_users(self.id, !new_record?)
    elsif is_private_changed? || non_private_domain_user_ids_changed?
      Domain.delay_for(5.seconds, queue: 'low').update_user_domain_caches(self.id)
    end
  end

  # Call from before destroy
  def do_unlink_users
    Domain.delay(queue: 'low').clear_user_caches(self.user_ids)
  end

end
