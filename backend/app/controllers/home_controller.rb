class HomeController < ApplicationController

  # GET /
  # This renders either the polymer layout if the user is logged in OR the public website
  def root
    if current_user
      redirect_to '/home'
    else
      respond_to do |format|
        format.html do 
          render_polymer_website('Badge List - Digital credentials for educators, companies and professional development orgs', {
            'include_metadata' => true,
            'metadata_title' => 'Overview of the Badge List Platform',
            'metadata_description' => 'Badge List helps educators, companies and professional development orgs create Open Badges ' \
              + 'to guide learning and recognize achievement.',
            'metadata_image' => bl_asset_url('badge-list-icon.png'),
            'metadata_image_width' => '500',
            'metadata_image_height' => '500',
            'metadata_site_name' => 'Badge List',
            'metadata_url' => request.original_url
          })
        end
        format.any do
          # This prevents an exception from occuring when random search engines try querying
          # for other home page formats
          not_found
        end
      end
    end
  end

  # GET /home
  def root_internal
    render_polymer_app('Home - Badge List')
  end
  
  # GET /w
  # This allows internal users to access the external homepage.
  def root_external
    if current_user
      render_polymer_website('Badge List - Digital credentials for educators, companies and professional development orgs', {
        'include_metadata' => true,
        'metadata_title' => 'Badge List',
        'metadata_description' => 'Badge List helps educators, companies and professional development orgs create Open Badges ' \
          + 'to guide learning and recognize achievement.',
        'metadata_image' => bl_asset_url('badge-list-icon.png'),
        'metadata_image_width' => '500',
        'metadata_image_height' => '500',
        'metadata_site_name' => 'Badge List',
        'metadata_url' => request.original_url
      })
    else
      # This prevents the '/w' URL from being bookmarked or used when people aren't logged in
      redirect_to '/'
    end
  end

  # GET /pricing
  def pricing
    # Update analytics if logged in
    if current_user
      IntercomEventWorker.perform_async({
        'event_name' => 'viewed-pricing',
        'email' => current_user.email,
        'created_at' => Time.now.to_i
      })
    end

    render_polymer_website(
      'Badge List Pricing', {
        'include_metadata' => true,
        'metadata_title' => 'Badge List Pricing',
        'metadata_description' => 'Badge List offers a free forever tier and an array of paid plans for organizations of all sizes.',
        'metadata_image' => bl_asset_url('badge-list-icon.png'),
        'metadata_image_width' => '500',
        'metadata_image_height' => '500',
        'metadata_site_name' => 'Badge List',
        'metadata_url' => request.original_url
    })
  end

  # GET /pricing_k12
  def pricing_k12
    redirect_to '/pricing#k12'
  end

  # GET /how-it-works
  def how_it_works
    render_polymer_website(
      'How Badge List Works - Expert validated ePortfolios for recognizing digital learning and professional development', {
        'include_metadata' => true,
        'metadata_title' => 'How Badge List Works',
        'metadata_description' => 'Badge List is built around a robust evidence and feedback collection workflow. ' \
          + 'Each badge is backed by a portfolio of evidence and the endorsements of experts.',
        'metadata_image' => bl_asset_url('graphics/badge-list-flow-diagram.png'),
        'metadata_image_width' => '2000',
        'metadata_image_height' => '699',
        'metadata_site_name' => 'Badge List',
        'metadata_url' => request.original_url
    })
  end

  # GET /privacy-policy
  def privacy_policy
    render_polymer_website('Privacy Policy - Badge List')
  end

  # GET /terms-of-service
  def terms_of_service
    render_polymer_website('Terms of Service - Badge List')
  end

end
