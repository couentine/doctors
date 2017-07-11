class AdminPagesController < ApplicationController

  before_action :badge_list_admin
  
  # GET /a
  # This shows the main admin tools menu
  def index
    # Nothing to do here
  end

  # GET /a/metrics?date=2017-02-01
  # This is the monthly metrics panel, it accepts a date parameter which is used only to get the 
  # month used for the metrics. (The specific day will always be overwritten to be 1.)
  # Each metric group is returned as an array of hashes with keys = :label, :description, :value
  #
  # NOTE: This is a resource-intensive page, but it's not a huge deal since it's only available
  #       to Badge List admins
  def metrics
    @date = (params['date'].blank?) ? Date.today : Date.parse(params['date'])
    @date = @date.beginning_of_month

    # Now build a list of date links that will be displayed up top
    # It will be an array of hashes with keys = :date, :label, :selected
    # We will display 7 months either centered on the selected month OR ending with the current
    # calendar month (if centering on the selected month would take us into the future)
    last_month_in_list = [@date + 3.months, Date.today.beginning_of_month].min
    @date_links = (-6..0).to_a.map do |delta|
      {
        date: last_month_in_list + delta.months,
        label: (last_month_in_list + delta.months).strftime('%Y-%m'),
        selected: (last_month_in_list + delta.months) == @date
      }
    end

    # Now set query filter variables
    this_month_start = @date.beginning_of_day
    this_month_end = @date.end_of_month.end_of_day
    last_month_end = (@date - 1).end_of_day
    last_month_start = last_month_end.beginning_of_month.beginning_of_day

    # User Metrics
    @user_metrics = [
      {
        label: 'Monthly Total Users',
        description: 'Total user count as of the end of this month',
        value: User.where(:created_at.lte => this_month_end).count
      },
      {
        label: 'Monthly Active Users',
        description: 'Users last active in this month (loses accuracy with time)',
        value: User.where(
            :last_active.gte => this_month_start,
            :last_active.lte => this_month_end
          ).count
      },
      { 
        label: 'Monthly New Users',
        description: 'Users created this month',
        value: User.where(
            :created_at.gte => this_month_start,
            :created_at.lte => this_month_end
          ).count
      },
      { 
        label: 'Monthly New Group Creators',
        description: 'Users created this month who have since created at least one group ' \
          + '(can increase with time)',
        value: User.where(
            :created_at.gte => this_month_start,
            :created_at.lte => this_month_end
          ).count{ |user| !user.created_group_ids.blank? } # NOTE: Querying directly doesn't work
                                  # >> I tried doing 'created_group_ids.0'.exists but it returned 0
      },
      { 
        label: 'Monthly Churned Users',
        description: 'Users created last month and not seen since (can decrease with time)',
        value: User.where(
            :created_at.gte => last_month_start,
            :created_at.lte => last_month_end,
            :last_active.lte => last_month_end
          ).count
      },
      { 
        label: 'Monthly Churned Group Creators',
        description: 'New group creators from last month not seen since (can decrease with time)',
        value: User.where(
            :created_at.gte => last_month_start,
            :created_at.lte => last_month_end,
            :last_active.lte => last_month_end
          ).count{ |user| !user.created_group_ids.blank? } # NOTE: Querying directly doesn't work
                                  # >> I tried doing 'created_group_ids.0'.exists but it returned 0
      }
    ]

    # Group Metrics
    
    # First we calculate monthly active groups work from entries to logs to badges to groups
    
    entry_log_ids = Entry.where(
        :created_at.gte => this_month_start, 
        :created_at.lte => this_month_end
      ).map{ |entry| entry.log_id }.uniq
    
    log_badge_ids = Log.where(:id.in => entry_log_ids).map{ |log| log.badge_id }
    log_badge_ids += Log.where(
        :created_at.gte => this_month_start, 
        :created_at.lte => this_month_end
      ).map{ |log| log.badge_id }
    log_badge_ids = log_badge_ids.uniq

    badge_group_ids = Badge.where(:id.in => log_badge_ids).map{ |badge| badge.group_id }
    badge_group_ids += Badge.where(
        :created_at.gte => this_month_start, 
        :created_at.lte => this_month_end
      ).map{ |badge| badge.group_id }
    badge_group_ids = badge_group_ids.uniq

    monthly_active_group_count = badge_group_ids.count
    
    # Now build the return value
    @group_metrics = [
      {
        label: 'Monthly Total Groups',
        description: 'Total group count as of the end of this month',
        value: Group.where(:created_at.lte => this_month_end).count
      },
      {
        label: 'Monthly Active Groups',
        description: 'Total groups with a badge, log or entry created this month',
        value: monthly_active_group_count
      },
      {
        label: 'Monthly Active Subscriptions',
        description: 'Total groups with subscriptions active during this month',
        value: Group.where(
            :subscription_plan.nin => [nil, 'free-5m-1'], 
            :subscription_end_date.gte => this_month_start
          ).count
      },
      {
        label: 'Monthly Canceled Subscriptions',
        description: 'Groups whose subscriptions ended this month',
        value: Group.where(
            :subscription_plan.nin => [nil, 'free-5m-1'], 
            :stripe_subscription_status => 'canceled',
            :subscription_end_date.gte => this_month_start,
            :subscription_end_date.lte => this_month_end
          ).count
      }
    ]

    # Badge Metrics
    @badge_metrics = [
      {
        label: 'Monthly Total Badges',
        description: 'Total badge count as of the end of this month',
        value: Badge.where(:created_at.lte => this_month_end).count
      },
      {
        label: 'Monthly Created Badges',
        description: 'Badges created this month',
        value: Badge.where(
            :created_at.gte => this_month_start,
            :created_at.lte => this_month_end
          ).count
      },
      {
        label: 'Monthly Awarded Badges',
        description: 'Validated logs issued this month',
        value: Log.where(
            :validation_status => 'validated',
            :date_issued.gte => this_month_start,
            :date_issued.lte => this_month_end
          ).count
      },
    ]
  end

private

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

end
