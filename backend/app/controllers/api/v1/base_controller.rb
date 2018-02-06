class Api::V1::BaseController < ApplicationController

  protect_from_forgery with: :null_session

  rescue_from Mongoid::Errors::DocumentNotFound, with: :not_found!

  def not_found!
    return api_error(status: 404, errors: ['Not found'])
  end  

  def api_error(status: 500, errors: [])
    unless Rails.env.production?
      puts errors.full_messages if errors.respond_to? :full_messages
    end
    head status: status and return if errors.empty?

    render json: { errors: errors }, status: status
  end

  def get_pagination_variables
    return {
      page: @page,
      page_size: @page_size,
      previous_page: @previous_page,
      next_page: @next_page,
      last_page: @last_page
    }
  end

  def set_initial_pagination_variables
    @page_size = (params['page_size'] || APP_CONFIG['page_size_small']).to_i
    @page = (params[:page] || 1).to_i
    @previous_page = (@page > 1) ? (@page - 1) : nil
  end
  
  def set_calculated_pagination_variables(query_criteria)
    query_count = query_criteria.count
    
    if query_count > (@page_size * @page)
      @next_page = @page + 1
    else
      @next_page = nil
    end

    @last_page = (query_count / (@page_size.to_f)).ceil
  end

end