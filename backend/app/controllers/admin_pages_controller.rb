class AdminPagesController < ApplicationController

  before_action :badge_list_admin
  
  # GET /a
  # This shows the main admin tools menu
  def index
    # Nothing to do here
  end

  # GET /a/metrics?date=2017-02-01
  # GET /a/metrics?poller=abc123
  # This is the monthly metrics panel, it accepts a date parameter which is used only to get the 
  # month used for the metrics. (The specific day will always be overwritten to be 1.)
  # Each metric group is returned as an array of hashes with keys = :label, :description, :value
  #
  # NOTE: This is a resource-intensive page, but it's not a huge deal since it's only available
  #       to Badge List admins
  def metrics
    if params['poller'].present?
      @poller = Poller.find(params['poller'])
      @date = Date.parse(@poller.data['date'])

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

      @user_metrics = @poller.data['user_metrics']
      @group_metrics = @poller.data['group_metrics']
      @badge_metrics = @poller.data['badge_metrics']
    else
      @date = (params['date'].blank?) ? Date.today : Date.parse(params['date'])
      @date = @date.beginning_of_month

      @poller = Poller.new(waiting_message: "Generating admin metrics for #{@date.to_s(:full_date)}...")
      @poller.progress = 1
      @poller.save

      AdminMetricsWorker.perform_async(@date, @poller.id)

      redirect_to poller_path(@poller)
    end
  end

  def icons
  end

private

  def badge_list_admin
    unless current_user && current_user.admin?
      redirect_to '/'
    end  
  end

end
