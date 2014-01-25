class TagsController < ApplicationController

  prepend_before_filter :find_all_records
  before_filter :authenticate_user!, only: [:edit, :update, :destroy]
  before_filter :can_view_tag, only: [:show]
  before_filter :badge_expert_or_learner, only: [:edit, :update]

  # === RESTFUL ACTIONS === #

  # GET /tags/1
  # GET /tags/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @tag }
    end
  end

  # GET /tags/1/edit
  def edit
    # Nothing to do here
  end

  # POST
  # PUT /tags/1
  # PUT /tags/1.json
  def update

    respond_to do |format|
      if @tag.update_attributes(params[:tag])
        format.html { redirect_to @tag, notice: 'Tag was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @tag.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/1
  # DELETE /tags/1.json
  def destroy
    @tag.destroy

    respond_to do |format|
      format.html { redirect_to tags_url }
      format.json { head :no_content }
    end
  end

private

  def find_all_records
    @group = Group.find(params[:group_id].to_s.downcase)
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase)
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    @current_user_log = current_user.logs.find_by(badge: @badge) rescue nil if current_user

    # Try to find the tag
    @tag = @badge.tags.find_by(name: (params[:tag_id] || params[:id]).to_s.downcase) rescue nil
    @tag_exists = !@tag.nil?

    # If the tag doesn't exist yet then create one in case the user wants to edit it
    if !@tag_exists
      @tag = Tag.new(name_with_caps: (params[:tag_id] || params[:id]))
      @tag.badge = @badge
    end
  end

  def can_view_tag
  end

  def badge_expert_or_learner
  end  

end

