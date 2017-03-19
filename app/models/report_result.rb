class ReportResult
  include Mongoid::Document
  include Mongoid::Timestamps
  include JSONTemplater

  # ============================================================================================= #
  # NOTE: The results are generated via an after_create callback, so generally you will want to
  #       use ReportResult.create_async() to make a new result item. 
  # ============================================================================================= #
  
  # === CONSTANTS === #

  TYPE_VALUES = ['group_users', 'group_badge_logs']
  FORMAT_VALUES = ['json', 'csv']
  STATUS_VALUES = ['pending', 'successful', 'failed']
  SORT_ORDER_VALUES = ['asc', 'desc'] # NOTE: This isn't enforced in a validator
  DELETE_AFTER = 2.hours # old report results are automatically deleted
  PAGE_SIZE = 200

  JSON_TEMPLATES = {
    detail: [:id, :user_id, :type, :format, :status, :error_message, :parameters, :sort_field,
      :sort_order, :page, :results, :total_result_count, :report_type_label, :report_type_icon, 
      :display_name],
    list_item: [:id, :user_id, :type, :format, :status, :error_message, :sort_field, :sort_order, 
      :page, :total_result_count, :report_type_label, :report_type_icon, :display_name, :full_path,
      :full_url]
  }

  # === RELATIONSHIPS === #

  belongs_to :user

  # === FIELDS & VALIDATIONS === #

  field :type,                    type: String
  field :format,                  type: String
  field :status,                  type: String, default: 'pending'
  field :error_message,           type: String # set if status = 'failed'
  
  field :parameters,              type: Hash, default: {}, pre_processed: true
  field :cleaned_parameters,      type: Hash, default: {}, pre_processed: true
  field :sort_field,              type: String # json only, should be REPORT_TYPE_VALUES key
  field :sort_order,              type: String # json only, should be 'asc' or 'desc'
  field :page,                    type: Integer # json only, defaults to 1
  field :results,                 type: Array, default: [], pre_processed: true
  field :total_result_count,      type: Integer # automatically set to total row count
  field :poller_id,               type: BSON::ObjectId # keep poller model lean = no relationships

  mount_uploader :results_file,   OutputFileUploader # used to upload csv format to S3

  validates :user, presence: true
  validates :type, presence: true,
    inclusion: { in: TYPE_VALUES, message: "%{value} is not a valid type" }
  validates :format, presence: true,
    inclusion: { in: FORMAT_VALUES, message: "%{value} is not a valid format" }
  validates :status, presence: true,
    inclusion: { in: STATUS_VALUES, message: "%{value} is not a valid status" }
  validate :clean_parameters

  # === CALLBACK === #

  after_create :generate_results
  before_update :upload_results_file
  after_save :queue_delete
  before_destroy :remove_results_file

  # === REPORT TYPE CONFIGUATION === #

  # This is used to display the different types of reports to the user
  # The icon value should be a material design iron-icon. List here: http://bit.ly/2nE9YrJ
  REPORT_TYPES = {
    'group_users' => { label: 'Group Members', icon: 'social:people' },
    'group_badge_logs' => { label: 'Badge Portfolios', icon: 'icons:assignment-ind' }
  }
  
  # This constant defines all of the parameters which are accepted for each report type
  # The spec for each parameter is used to validate it in the clean_parameters method
  REPORT_TYPE_PARAMETERS = {
    'group_users' => {
      'group_id' => { type: BSON::ObjectId, label: 'Group', required: true },
      'group_tag_id' => { type: BSON::ObjectId, label: 'Group Tag' }
    },
    'group_badge_logs' => {
      'group_id' => { type: BSON::ObjectId, label: 'Group', required: true },
      'group_tag_id' => { type: BSON::ObjectId, label: 'Group Tag' },
      'validation_status' => { type: String, label: 'Badge Status' },
      'created_at_start' => { type: Date, label: 'Badge Join Start Date' },
      'created_at_end' => { type: Date, label: 'Badge Join End Date' },
      'date_issued_start' => { type: Date, label: 'Badge Award Start Date' },
      'date_issued_end' => { type: Date, label: 'Badge Award End Date' }
    }
  }

  # This constant defines the primary model which is used for pagination for each record type
  REPORT_TYPE_CORE_MODEL = {
    'group_users' => :user,
    'group_badge_logs' => :log
  }

  # This constant defines the default sort_field for each report type
  # NOTE: The value must be a key for on of the fields from the CORE_MODEL listed above
  REPORT_TYPE_DEFAULT_SORT_FIELD = {
    'group_users' => 'name',
    'group_badge_logs' => 'portfolio_created'
  }

  # This constant defines the values which are returned in each row of results for each report type
  # For each report type there should be one sub-key for each object returned in a row of results
  # The sub-key array members should have a :key (for json), a :label (for csv) and a :value.
  # The :value should be the name of a field or method on the model class.
  # The values are retrieved using the model.send() method. You can chain multiple items with a dot
  # but you can't add parameters or anything like that.
  # VALID EXAMPLES for a badge: 'name', 'image_url', 'group.owner.name'
  # INVALID EXAMPLES for a badge: 'image_url(:medium)'
  REPORT_TYPE_VALUES = {
    'group_users' => {
      user: [
        { key: 'name', label: 'Name', value: 'name' },
        { key: 'username', label: 'Username', value: 'username_with_caps' },
        { key: 'email', label: 'Email', value: 'email' },
        { key: 'organization_name', label: 'Organization Name', value: 'organization_name' },
        { key: 'job_title', label: 'Job Title', value: 'job_title' },
        { key: 'last_active', label: 'Last Active', value: 'last_active' }
      ],
      group_log_summary: [
        { key: 'joined_badge_count', label: 'Joined Badge Count', value: 'log_count' },
        { key: 'awarded_badge_count', label: 'Awarded Badge Count', value: 'validated_log_count' }
      ]
    },
    'group_badge_logs' => {
      badge: [
        { key: 'badge_name', label: 'Badge Name', value: 'name' },
        { key: 'badge_url', label: 'Badge URL', value: 'url_with_caps' }
      ],
      user: [
        { key: 'user_name', label: 'User Name', value: 'name' },
        { key: 'user_username', label: 'User Username', value: 'username_with_caps' },
        { key: 'user_email', label: 'User Email', value: 'email' },
        { key: 'user_organization_name', label: 'User Organization Name', 
          value: 'organization_name' },
        { key: 'user_job_title', label: 'User Job Title', value: 'job_title' }
      ],
      log: [
        { key: 'portfolio_status', label: 'Portfolio Status', value: 'validation_status' },
        { key: 'portfolio_retracted', label: 'Portfolio Retracted', value: 'retracted' },
        { key: 'portfolio_created', label: 'Portfolio Created', value: 'date_started' },
        { key: 'portfolio_awarded', label: 'Portfolio Awarded', value: 'date_issued' }
      ]
    }
  }

  # === CLASS METHODS === #

  # This calls the standard create method in a background thread and returns a poller id. 
  def self.create_async(attributes = nil)
    poller = Poller.new
    poller.waiting_message = 'Building report results'
    poller.save

    attributes[:poller_id] = poller.id
    ReportResult.delay(queue: 'default', retry: false).create(attributes)

    poller.id
  end

  def self.delete_report_result(report_result_id)
    report_result = ReportResult.find(report_result_id) rescue nil
    report_result.delete if report_result
  end
  
  # === INSTANCE METHODS === #

  def full_path
    "/report_results/#{id.to_s}"
  end

  def full_url
    "#{ENV['root_url'] || 'https://www.badgelist.com'}#{full_path}"
  end

  def report_type_label
    (REPORT_TYPES.has_key? type) ? REPORT_TYPES[type][:label] : ''
  end
  
  def report_type_icon
    (REPORT_TYPES.has_key? type) ? REPORT_TYPES[type][:icon] : ''
  end

  def display_name
    "#{report_type_label} - #{created_at.to_s(:full_date_time)}"
  end

  def completed
    (status == 'successful') || (status == 'failed')
  end

protected
  
  # This builds the cleaned_parameters hash and adds errors if there are invalid parameters
  # This method also checks that sort_field and page have valid values
  def clean_parameters
    object_cache = {}
    core_model_field_keys = []

    # Don't bother checking the parameters if there are other errors already
    if errors.blank?

      # First clean up the sort parameters
      self.page = 1 if (format == 'json') && (page.blank? || (page < 1))
      self.sort_order = 'asc' if !SORT_ORDER_VALUES.include?(sort_order)
      core_model_field_keys = REPORT_TYPE_VALUES[type][REPORT_TYPE_CORE_MODEL[type]]\
        .map{ |field| field[:key] }
      if !core_model_field_keys.include? sort_field
        self.sort_field = REPORT_TYPE_DEFAULT_SORT_FIELD[type]
      end

      # Verify the presence and format of all parameters and build cleaned_parameters
      self.cleaned_parameters = {}
      REPORT_TYPE_PARAMETERS[type].each do |name, spec|
        value = parameters[name]

        # Check for presence of required params
        if spec[:required] && value.blank?
          errors.add(:parameters, spec[:label] + ' value is required')
        end

        # Now verify that fields which are set are valid, then add them to cleaned_parameters
        if !value.blank?
          case spec[:type]
          when BSON::ObjectId
            if BSON::ObjectId.legal?(value)
              self.cleaned_parameters[name] = BSON::ObjectId.from_string(value)
            else
              errors.add(:parameters, spec[:label] + ' value is not a valid id')
            end
          when Date
            self.cleaned_parameters[name] = Date.parse(value) rescue nil
            if cleaned_parameters[name].nil?
              errors.add(:parameters, spec[:label] + ' value is not a valid date')
            end
          else
            self.cleaned_parameters[name] = value
          end
        end
      end

      # If we haven't gotten any errors yet then we proceed to object id validation
      if errors.blank?
        # We loop through looking for specific parameters names which we know correspond to record
        # ids which need to be verified. It's important that parameter names be consistent in order
        # for this logic to work.
        REPORT_TYPE_PARAMETERS[type].each do |name, spec|
          
          value = cleaned_parameters[name]

          if !value.blank?
            case name
            when 'group_id'
              group = Group.find(value) rescue nil

              if group.nil?
                self.cleaned_parameters[name] = nil
                errors.add(:parameters, 'Group id is invalid')
              elsif !user.admin_of?(group) && !user.admin
                errors.add(:parameters, 'You do not have reporting permissions for this group')
              else
                object_cache[:group] = group
              end
            when 'group_tag_id'
              group = object_cache[:group]
              if group.nil?
                errors.add(:parameters, 'Group must be set in order to specify a group tag')
              else
                group_tag = GroupTag.find(value) rescue nil

                if group_tag.nil?
                  self.cleaned_parameters[name] = nil
                  errors.add(:parameters, 'Group tag id is invalid')
                elsif group_tag.group_id != group.id
                  errors.add(:parameters, 'The specified group tag is in a different group')
                else
                  object_cache[:group_tag] = group_tag
                end
              end
            end
          end

        end
      end

    end
  end

  # This is the method that actually builds out the results based on the type and cleaned_parameters
  # If the poller_id property is set, then this method will keep that poller updated as the report
  # generation progresses
  def generate_results
    self.error_message = nil
    self.results = []

    # First get the poller if needed
    poller = Poller.find(poller_id) if poller_id

    # Get the source rows from the appropriate method below
    source_rows = self.send('build_source_rows_for_' + type)

    if self.error_message.blank?
      # If this is a csv file then the first row needs to contain all of the field labels
      if format == 'csv'
        current_row = []
        REPORT_TYPE_VALUES[type].each do |model, fields|
          fields.each do |field|
            current_row << field[:label]
          end
        end
        self.results << current_row
      end

      # Now loop through each source row and render the result row
      source_rows.each do |row|
        current_row = (format == 'json') ? {} : []

        REPORT_TYPE_VALUES[type].each do |model, fields|
          fields.each do |field|
            if row[model].class == Hash
              # We use hashes to mock up summary fields, but they don't support 'send()'
              current_value = row[model][field[:value]]
            else
              current_value = row[model].send(field[:value])
            end

            if format == 'json'
              current_row[field[:key]] = current_value
            else
              current_row << current_value.to_s
            end
          end
        end

        self.results << current_row
      end

      # We're good to go!
      self.status = 'successful'
    else
      self.status = 'failed'
    end

    # Commit everything to the DB (this will trigger the CSV upload if needed)
    self.save
    if poller
      poller.status = status
      poller.message = error_message || 'Report results complete'
      poller.redirect_to = "report_result/#{id.to_s}"
      poller.save
    end
  end

  # Returns source rows for group_users report, sets error_message if there is an exception.
  # Each source row has two keys (:user and :group_log_summary)
  def build_source_rows_for_group_users
    rows = []
    row_map = {} # user_id => row_for_that_user
    user_ids = [] # array of ids in this current page

    begin
      # First query the parameter objects
      group = Group.find(cleaned_parameters['group_id'])
      if !cleaned_parameters['group_tag_id'].blank?
        group_tag = GroupTag.find(cleaned_parameters['group_tag_id'])
      end

      # Now initialize the user criteria
      sort_field_item = REPORT_TYPE_VALUES[type][REPORT_TYPE_CORE_MODEL[type]]\
        .find{ |field| field[:key] == sort_field }
      user_criteria = (group_tag) ? group_tag.users : group.users
      user_criteria = user_criteria.order_by("#{sort_field_item[:value]} #{sort_order}")
      
      # Now do the core query and build the rows (and the row map for later)
      self.total_result_count = user_criteria.count
      if format == 'json'
        user_criteria = user_criteria.page(page).per(PAGE_SIZE)
      end
      user_criteria.each do |user|
        current_row = { 
          user: user, 
          group_log_summary: { 'log_count' => 0, 'validated_log_count' => 0 } 
        }
        rows << current_row
        row_map[user.id] = current_row
        user_ids << user.id
      end

      # Now query for the logs and loop through them to build out the group_log_summary counts
      logs = Log.where(:user_id.in => user_ids, :badge_id.in => group.badges_cache.keys)
      logs.each do |log|
        row_map[log.user_id][:group_log_summary]['log_count'] += 1
        if log.validation_status = 'validated'
          row_map[log.user_id][:group_log_summary]['validated_log_count'] += 1
        end
      end
    rescue Exception => e
      self.error_message = e
      throw e
    end

    rows
  end
  
  # Returns source rows for group_badge_logs report, sets error_message if there is an exception.
  # Each source row has three keys (:badge, :user and :log)
  def build_source_rows_for_group_badge_logs
    rows = []
    user_row_map = {} # user_id => array_of_rows_for_user
    badge_row_map = {} # user_id => array_of_rows_for_badge
    user_ids = [] # array of ids in this current page
    badge_ids = [] # array of ids in this current page

    begin
      # First query the parameter objects
      group = Group.find(cleaned_parameters['group_id'])
      if !cleaned_parameters['group_tag_id'].blank?
        group_tag = GroupTag.find(cleaned_parameters['group_tag_id'])
      end

      # Now initialize the log criteria
      sort_field_item = REPORT_TYPE_VALUES[type][REPORT_TYPE_CORE_MODEL[type]]\
        .find{ |field| field[:key] == sort_field }
      if group_tag
        all_user_ids = group_tag.user_ids
      else
        all_user_ids = (group.member_ids + group.admin_ids).uniq
      end
      log_criteria = Log.where(:user_id.in => all_user_ids, 
        :badge_id.in => group.badges_cache.keys)\
        .order_by("#{sort_field_item[:value]} #{sort_order}")

      # Next we add all of the optional parameters to the criteria
      cp = cleaned_parameters # alias / shortcut
      if cp['validation_status']
        log_criteria = log_criteria.where(validation_status: cp['validation_status'])
      end
      if cp['created_at_start']
        log_criteria = log_criteria.where(:created_at.gte => cp['created_at_start'])
      end
      if cp['created_at_end']
        log_criteria = log_criteria.where(:created_at.lte => cp['created_at_end'])
      end
      if cp['date_issued_start']
        log_criteria = log_criteria.where(:date_issued.gte => cp['date_issued_start'])
      end
      if cp['date_issued_end']
        log_criteria = log_criteria.where(:date_issued.lte => cp['date_issued_end'])
      end
      
      # Now do the core query and build the rows (and the row maps for later)
      self.total_result_count = log_criteria.count
      if format == 'json'
        log_criteria = log_criteria.page(page).per(PAGE_SIZE)
      end
      log_criteria.each do |log|
        current_row = { log: log }
        rows << current_row
        
        user_ids << log.user_id unless user_ids.include? log.user_id
        if user_row_map.has_key? log.user_id
          user_row_map[log.user_id] << current_row
        else
          user_row_map[log.user_id] = [current_row]
        end
        
        badge_ids << log.badge_id unless badge_ids.include? log.badge_id
        if badge_row_map.has_key? log.badge_id
          badge_row_map[log.badge_id] << current_row
        else
          badge_row_map[log.badge_id] = [current_row]
        end
      end

      # Next we query users
      users = User.where(:id.in => user_ids)
      users.each do |user|
        user_row_map[user.id].each do |row|
          row[:user] = user
        end
      end

      # Finally we query badges
      badges = Badge.where(:id.in => badge_ids)
      badges.each do |badge|
        badge_row_map[badge.id].each do |row|
          row[:badge] = badge
        end
      end      
    rescue Exception => e
      self.error_message = e
    end

    rows
  end

  # Call from after update, checks if results have changed and the format is csv
  # If so it will upload the csv to S3
  def upload_results_file
    # NOTE that even a "blank" report will have one row in results
    if results_changed? && !results.blank? && (format == 'csv')
      # Create a temp file and then use it to build the csv
      output_file_path = "#{Rails.root}/tmp/report_result_#{id.to_s}.csv"
      output_file = CSV.open(output_file_path, 'wb') do |csv|
        results.each do |row|
          csv << row
        end
      end
      
      # Now store the file in S3
      self.results_file = Pathname.new(output_file_path).open
    end
  end

  # This should be called before destroy, it deletes the uploaded results file from S3
  def remove_results_file
    if results_file && results_file.url.blank?
      self.remove_results_file!
    end
  end

  # Call from after save, it queues the automatic deletion of the record when completed
  def queue_delete
    ReportResult.delay_for(DELETE_AFTER).delete_report_result(id.to_s) if completed
  end

end
