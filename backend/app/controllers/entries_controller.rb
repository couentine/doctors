class EntriesController < ApplicationController
  prepend_before_action :find_parent_records, except: [:show, :edit, :update, :destroy]
  prepend_before_action :find_all_records, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, only: [:edit, :new, :create, :update, :destroy]
  before_action :visible_to_current_user, only: [:show]
  before_action :entry_creator, only: [:edit, :update]
  before_action :log_owner_or_entry_creator, only: [:destroy]
  before_action :can_post_to_log, only: [:new, :create]

  # === LIMIT-FOCUSED FILTERS === #

  before_action :can_create_entries, only: [:new, :create]

  # === RESTFUL ACTIONS === #

  # GET /group-url/badge-url/u/username/1
  # GET /group-url/badge-url/u/username/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @entry, filter_user: current_user }
    end
  end

  # This returns a form for a POST type entry by default.
  # To specify a validation, include "type" parameter set to "validation"
  # NOTE: Will redirect to EDIT for validations that already exist
  # GET /group-url/badge-url/u/username/entries/new => NEW POST
  # GET /group-url/badge-url/u/username/entries/new?f=tweet => NEW POST w/ format = tweet
  # GET /group-url/badge-url/u/username/entries/new?type=validation => NEW VALIDATION
  # GET /group-url/badge-url/u/username/entries/new.json
  # Accepts "tag" parameter
  def new
    @type = params[:type] || 'post'
    @manual_format = params[:f]

    if @type == 'validation'
      @entry = current_user.created_entries.find_by(log: @log, type: 'validation') rescue nil
      @validation_already_exists = !@entry.nil?
      if @validation_already_exists
        render :edit
      else
        @entry = Entry.new
        @entry.type = 'validation'
        render :new
      end
    else
      # Create the entry
      @parent_tag_name = params[:tag]
      @entry = Entry.new(parent_tag: @parent_tag_name)
      @entry.type = 'post'
      
      # Query the parent tag if present
      @parent_tag = nil
      if !@parent_tag_name.blank?
        matched_tags = @badge.tags.where(name: @parent_tag_name.downcase)
        if matched_tags.count > 0
          @parent_tag = matched_tags.first
          if (@parent_tag.format == 'any') && Entry::FORMAT_VALUES.include?(@manual_format)
            @entry.format = @manual_format
            if (@entry.format == 'file') && !@group.has?(:file_uploads)
              flash[:error] = 'Oops! This group does not support file uploads.'
              @entry.format = nil
            end
          else
            @entry.format = @parent_tag.format
          end
        elsif Entry::FORMAT_VALUES.include?(@manual_format)
          @entry.format = @manual_format
        end
      end

      # Create the carrierwave direct uploader if this is an image or a file
      if @entry.format == 'image'
        @entry.uploaded_image_key = params[:key]
        @image_uploader = Entry.new.direct_uploaded_image
        @image_uploader.success_action_redirect = request.original_url
      elsif @entry.format == 'file'
        @entry.uploaded_file_key = params[:key]
        @file_uploader = Entry.new.direct_uploaded_file
        @file_uploader.success_action_redirect = request.original_url
      end

      render :new
    end
  end

  # GET /group-url/badge-url/u/username/1/edit
  def edit
    # Create the carrierwave direct uploader if this is an image or a file
    if @entry.format == 'image'
      @image_uploader = Entry.new.direct_uploaded_image
      @image_uploader.success_action_redirect = request.original_url
      @entry.uploaded_image_key = params[:key] if params[:key]
    elsif @entry.format == 'file'
      @file_uploader = Entry.new.direct_uploaded_file
      @file_uploader.success_action_redirect = request.original_url
      @entry.uploaded_file_key = params[:key] if params[:key]
    end
  end

  # POST /group-url/badge-url/u/username/entries
  # POST /group-url/badge-url/u/username/entries.json
  def create
    @type = params[:entry][:type] || 'post'

    # First create the entry
    if @type == 'validation'
      # First determine if the validation already exists
      existing_entry = current_user.created_entries.find_by(log: @log, type: 'validation') rescue nil
      @validation_already_exists = !existing_entry.nil? # only used to set the flash message
      # logger.debug "+++create: params[:entry][:log_validated] = #{params[:entry][:log_validated]}+++"
      @log_validated = (params[:entry][:log_validated] == 'true')

      # Now add the validation using the standard field (thus preventing duplicates)
      @entry = @log.add_validation(current_user, params[:entry][:summary], params[:entry][:body], @log_validated)
    else
      @entry = Entry.new(entry_params)
      @entry.type = 'post'
      @entry.log = @log
      @entry.creator = current_user
      @entry.current_user = current_user
      @entry.current_username = current_user.username
      
      @entry.save # This commits the save to S3 for images and thus can error out
      # begin
      # rescue => e
      #   @entry.errors[:base] << "There was an error saving your #{@type}. Please try again later."

      #   # Create the carrierwave direct uploader if this is an image
      #   if @entry.format == 'image'
      #     @uploader = @entry.direct_uploaded_image
      #     @uploader.success_action_redirect = request.original_url
      #   end
      # end
    end

    # Now do the redirect
    if @entry.errors.count > 0
      # Create the carrierwave direct uploader if this is an image or a file
      if @entry.format == 'image'
        @image_uploader = Entry.new.direct_uploaded_image
        @image_uploader.success_action_redirect = request.original_url
      elsif @entry.format == 'file'
        @file_uploader = Entry.new.direct_uploaded_file
        @file_uploader.success_action_redirect = request.original_url
      end

      if @entry.new_record?
        flash[:error] = "There was an error creating your #{@type}."
        render :new
      else
        flash[:error] = "There was an error updating your #{@type}."
        render :edit
      end
    else
      if (@type == 'validation') 
        if @validation_already_exists
          notice = "Your feedback was updated."
        else
          notice = "Your feedback was submitted."
        end
      else  
        notice = "Your evidence has been posted."
      end

      redirect_to [@group, @badge, @log], notice: notice
    end
  end

  # PUT /group-url/badge-url/u/username/1
  # PUT /group-url/badge-url/u/username/1.json
  def update
    @entry.current_user = current_user
    @entry.current_username = current_user.username

    respond_to do |format|
      if @entry.type == 'validation'
        @log.add_validation(current_user, params[:entry][:summary], params[:entry][:body], (params[:entry][:log_validated] == "true"),
          true, @entry.preserve_body_html)

        format.html do
          redirect_to [@group, @badge, @log, @entry], notice: 'Feedback was successfully updated.'
        end
        format.json { head :no_content }
      elsif @entry.update_attributes(entry_params)
        format.html do
          redirect_to [@group, @badge, @log, @entry], notice: 'Post was successfully updated.'
        end
        format.json { head :no_content }
      else
        format.html do
          if @entry.type == 'validation'
            render :edit
          else
            # Create the carrierwave direct uploader if this is an image
            if @entry.format == 'image'
              @image_uploader = @entry.direct_uploaded_image
              @image_uploader.success_action_redirect = request.original_url
            elsif @entry.format == 'file'
              @file_uploader = @entry.direct_uploaded_file
              @file_uploader.success_action_redirect = request.original_url
            end

            render :edit
          end
        end
        format.json { render json: @entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /group-url/badge-url/u/username/1
  # DELETE /group-url/badge-url/u/username/1.json
  def destroy
    @entry.destroy

    respond_to do |format|
      format.html { redirect_to [@group, @badge, @log] }
      format.json { head :no_content }
    end
  end

private

  def find_parent_records
    @group = Group.find(params[:group_id].to_s.downcase) || not_found
    @badge = @group.badges.find_by(url: params[:badge_id].to_s.downcase) || not_found
    @user = User.find(params[:log_id].to_s.downcase) || not_found # find user by username
    @log = @user.logs.find_by(badge: @badge) || not_found
    @current_user_is_admin = current_user && current_user.admin_of?(@group)
    @current_user_is_member = current_user && current_user.member_of?(@group)
    @current_user_is_expert = current_user && current_user.expert_of?(@badge)
    @current_user_is_learner = current_user && current_user.learner_of?(@badge)
    @current_user_is_log_owner = current_user && (current_user == @log.user)
    @badge_list_admin = current_user && current_user.admin?

    # Set current group (for analytics) only if user is logged in and an admin
    @current_user_group = @group if @current_user_is_admin

    # Define badge terminology shortcuts
    @expert = @badge.expert
    @experts = @badge.experts
    @Expert = @badge.Expert
    @Experts = @badge.Experts
    @learner = @badge.learner
    @learners = @badge.learners
    @Learner = @badge.Learner
    @Learners = @badge.Learners
    @show_progress = @badge.tracks_progress?

    # Build code language options
    @code_language_options = [['abap', 'abap'], ['abc', 'abc'],  
      ['actionscript', 'actionscript'], ['ada', 'ada'],  ['apache conf', 'apache_conf'], 
      ['applescript', 'applescript'], ['asciidoc', 'asciidoc'],  ['assembly x86', 'assembly_x86'], 
      ['autohotkey', 'autohotkey'], ['batchfile', 'batchfile'],  ['behaviour', 'behaviour'], 
      ['c9search', 'c9search'], ['c cpp', 'c_cpp'],  ['cirru', 'cirru'], ['clojure', 'clojure'], 
      ['cobol', 'cobol'], ['coffee', 'coffee'],  ['coffee worker', 'coffee_worker'], 
      ['coldfusion', 'coldfusion'], ['csharp', 'csharp'],  ['css', 'css'], 
      ['css worker', 'css_worker'], ['curly', 'curly'], ['d', 'd'],  
      ['dart', 'dart'], ['diff', 'diff'], ['django', 'django'], ['dockerfile', 'dockerfile'],  
      ['dot', 'dot'], ['eiffel', 'eiffel'], ['ejs', 'ejs'], ['elixir', 'elixir'],  ['elm', 'elm'], 
      ['erlang', 'erlang'], ['forth', 'forth'], ['ftl', 'ftl'],  ['gcode', 'gcode'], 
      ['gherkin', 'gherkin'], ['gitignore', 'gitignore'],  ['glsl', 'glsl'], ['golang', 'golang'], 
      ['groovy', 'groovy'], ['haml', 'haml'],  ['handlebars', 'handlebars'], ['haskell', 'haskell'],
      ['haxe', 'haxe'],  ['html', 'html'], ['html completions', 'html_completions'], 
      ['html ruby', 'html_ruby'],  ['html worker', 'html_worker'], ['ini', 'ini'], ['io', 'io'], 
      ['jack', 'jack'],  ['jade', 'jade'], ['java', 'java'], ['javascript', 'javascript'],  
      ['javascript worker', 'javascript_worker'], ['json', 'json'],  ['json worker', 'json_worker'],
      ['jsoniq', 'jsoniq'], ['jsp', 'jsp'], ['jsx', 'jsx'],  ['julia', 'julia'], ['latex', 'latex'],
      ['lean', 'lean'], ['less', 'less'],  ['liquid', 'liquid'], ['lisp', 'lisp'], 
      ['livescript', 'livescript'],  ['logiql', 'logiql'], ['lsl', 'lsl'], ['lua', 'lua'], 
      ['lua worker', 'lua_worker'],  ['luapage', 'luapage'], ['lucene', 'lucene'], 
      ['makefile', 'makefile'],  ['markdown', 'markdown'], ['mask', 'mask'],  
      ['matching brace outdent', 'matching_brace_outdent'],  
      ['matching parens outdent', 'matching_parens_outdent'], ['matlab', 'matlab'],  ['mel', 'mel'],
      ['mushcode', 'mushcode'], ['mysql', 'mysql'], ['nix', 'nix'],  ['objectivec', 'objectivec'], 
      ['ocaml', 'ocaml'], ['pascal', 'pascal'],  ['perl', 'perl'], ['pgsql', 'pgsql'], 
      ['php', 'php'], ['php worker', 'php_worker'],  ['plain text', 'plain_text'], 
      ['powershell', 'powershell'], ['praat', 'praat'],  ['prolog', 'prolog'], 
      ['properties', 'properties'], ['protobuf', 'protobuf'],  ['python', 'python'], ['r', 'r'], 
      ['rdoc', 'rdoc'], ['rhtml', 'rhtml'],  ['ruby', 'ruby'], ['rust', 'rust'], ['sass', 'sass'], 
      ['scad', 'scad'],  ['scala', 'scala'], ['scheme', 'scheme'], ['scss', 'scss'], ['sh', 'sh'], 
      ['sjs', 'sjs'], ['smarty', 'smarty'], ['snippets', 'snippets'],  
      ['soy template', 'soy_template'], ['space', 'space'], ['sql', 'sql'],  ['stylus', 'stylus'], 
      ['svg', 'svg'], ['tcl', 'tcl'], ['tex', 'tex'],  ['text', 'text'], ['textile', 'textile'], 
      ['toml', 'toml'], ['twig', 'twig'],  ['typescript', 'typescript'], ['vala', 'vala'], 
      ['vbscript', 'vbscript'],  ['velocity', 'velocity'], ['verilog', 'verilog'], ['vhdl', 'vhdl'], 
      ['xml', 'xml'],  ['xml worker', 'xml_worker'], ['xquery', 'xquery'], 
      ['xquery worker', 'xquery_worker'], ['yaml', 'yaml']];
  end

  def find_all_records
    find_parent_records

    @entry = @log.entries.find_by(entry_number: (params[:entry_id] || params[:id])) || not_found
    @parent_tag = @entry.tag
    @current_user_is_entry_creator = current_user && (current_user.id == @entry.creator_id)
    @visible_to_current_user = @badge_list_admin || @entry.visible_to?(current_user, @badge)

    if current_user.present?
      @current_user_log = current_user.logs.find_by(badge: @badge) rescue nil 
    end
  end

  def visible_to_current_user
    unless @visible_to_current_user
      flash[:error] = "Oops! it looks like you don't have access to this item."
      redirect_to [@group, @badge, @log]
    end
  end

  def entry_creator
    unless @current_user_is_entry_creator || @badge_list_admin
      flash[:error] = "That action is restricted to the entry creator."
      redirect_to [@group, @badge, @log, @entry]
    end
  end

  def log_owner_or_entry_creator
    unless @current_user_is_log_owner || @current_user_is_entry_creator || @badge_list_admin
      flash[:error] = "That action is restricted to the log owner or the entry creator."
      redirect_to [@group, @badge, @log, @entry]
    end
  end

  def can_post_to_log
    unless @current_user_is_expert || @current_user_is_admin || @current_user_is_log_owner \
        || @badge_list_admin
      flash[:error] = "You do not have permission to post to this log."
      redirect_to [@group, @badge, @log]
    end
  end

  def can_create_entries
    if @group.disabled?
      flash[:error] = "You cannot post evidence since this group is currently inactive."
      redirect_to @group
    end
  end

  def entry_params
    params.require(:entry).permit(:parent_tag, :summary, :format, :log_validated, :body, :link_url,
      :code_format, :uploaded_image_key, :uploaded_file_key)
  end

end