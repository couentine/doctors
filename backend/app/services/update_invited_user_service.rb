#==========================================================================================================================================#
# 
# INVITED USER INFO ITEM UPDATE SERVICE
# 
# This is called whenever the `posts` or `validations` are updated on an invited_user or invited_admin list on a group.
# 
#==========================================================================================================================================#

class UpdateInvitedUserService

  #=== CONSTANTS ===#

  INFO_ITEM_TYPE = 'invited-user'

  #=== ATTRIBUTES ===#

  attr_accessor :group
  attr_accessor :invited_user
  attr_accessor :user_key
  attr_accessor :info_item

  #=== METHODS ===#

  def initialize(group, invited_user)
    @group = group
    @invited_user = invited_user

    raise StandardError.new('Missing email') if @invited_user['email'].blank?

    @user_key = Digest::MD5.hexdigest(@invited_user['email'].downcase)
    @info_item = InfoItem.where(type: INFO_ITEM_TYPE, key: @user_key).first

    if @info_item.blank?
      @info_item = InfoItem.new(
        name: 'Invited User (No Name)',
        type: INFO_ITEM_TYPE,
        key: @user_key,
        data: {
          'name': 'Anonymous User',
        },
      )
    end
  end

  def perform
    @info_item.data[@group.id.to_s] = @invited_user

    if @invited_user['name'].present?
      @info_item.data['name'] = @invited_user['name']
      @info_item.name = "Invited User (#{@invited_user['name']})"
    end

    @info_item.save
  end

end