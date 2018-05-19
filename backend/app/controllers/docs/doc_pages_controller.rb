class Docs::DocPagesController < ApplicationController

  def index
    render_polymer_website(
      'Badge List Help Documentation', {
        'include_metadata' => true,
        'metadata_title' => 'Badge List Help Documentation',
        'metadata_description' => 'Badge List docs for users, admins and developers',
        'metadata_image' => bl_asset_url('badge-list-icon.png'),
        'metadata_image_width' => '500',
        'metadata_image_height' => '500',
        'metadata_site_name' => 'Badge List',
        'metadata_url' => request.original_url
    })
  end

end