require 'fileutils'

#=== CONSTANTS ===#

remotes = { # first is default
  'staging' => 'bl-staging-mango', 
  'production' => 'badgelist'
}

# If you need to manually build here is a version to copy and paste:
# polymer build --js-minify --css-minify --html-minify --bundle --add-service-worker --insert-prefetch-links
polymer_app_build_options = [
  '--js-minify',
  '--css-minify',
  '--html-minify',
  '--bundle',
  '--add-service-worker',
  '--insert-prefetch-links'
]

# This is the commit message used when committing the rebuilt polymer files to git (if needed)
POLYMER_REBUILD_COMMIT_MESSAGE = "Rebuilt polymer frontend."

#=== SCRIPT BANNER ===#

  puts "\n\n#===[BADGE LIST DEPLOYMENT SCRIPT]===#\n\n\n"

#=== CHECK GIT CONFIGURATION ===#

  puts "LOAD GIT CONFIGURATION"
  puts "================================================================================"

  # First we need to check that the git remotes are configured
  remotes.each do |remote_name, heroku_app_name|
    if `git remote get-url #{remote_name}`.empty?
      puts "===> '#{remote_name}' remote missing, adding..."
      system("heroku git:remote -a #{heroku_app_name} -r #{remote_name}")
    else
      puts "===> '#{remote_name}' remote present."
    end
  end

  # Then we get the branches
  branches = []
  current_branch = nil
  `git branch`.split("\n").each do |branch_list_item|
    if branch_list_item.include? '*'
      branch_list_item.gsub!(/\*/, '').strip!
      current_branch = branch_list_item
    end
    branches << branch_list_item.strip
  end
  current_branch ||= branches.first
  puts "===> Found #{branches.count} local branches."

  # Ensure that there are no untracked files
  uncommitted_changes = `git status --porcelain`
  if !uncommitted_changes.empty?
    puts "===> ERROR: Uncommitted changes found...\n#{uncommitted_changes}"
    puts "--------------------------------------------------------------------------------\n\n\n"
    puts "ERROR! You have uncommitted changes in your local git environment."
    puts "Please make sure all files are committed before continuing.\n\n"
    exit
  end

  # Get the various paths
  root_path = `git rev-parse --show-toplevel`.chomp
  backend_path = "#{root_path}/backend"
  frontend_path = "#{root_path}/frontend"
  polymer_app_path = "#{frontend_path}/app"
  polymer_app_build_source_path = "#{polymer_app_path}/build/default"
  polymer_app_build_target_path = "#{backend_path}/public/p/app"
  puts "===> Root path: #{root_path}"
  puts "===> Backend path: #{backend_path}"
  puts "===> Frontend path: #{frontend_path}"
  puts "===> Polymer build source path: #{polymer_app_build_source_path}"
  puts "===> Polymer build target path: #{polymer_app_build_target_path}"

  puts "--------------------------------------------------------------------------------\n\n\n"


#=== SELECT LOCAL BRANCH ===#

  puts "SELECT BRANCH TO DEPLOY"
  puts "================================================================================"

  puts "What local branch would you like to deploy from?"
  branches.each_with_index do |branch, index|
    puts "(#{index+1}) #{branch} #{(branch == current_branch) ? '***DEFAULT***' : ''}"
  end
  puts ""
  
  selected_branch = nil
  while selected_branch.nil?
    print "[Press Enter for DEFAULT] >> "
    selected_branch_input = gets.chomp
    if selected_branch_input.empty?
      selected_branch = current_branch
    else
      selected_branch_index = (Integer(selected_branch_input) rescue 0) - 1
      if (selected_branch_index < 0) || (selected_branch_index >= branches.count)
        puts "ERROR: You must enter a number from 1 to #{branches.count}."
      else
        selected_branch = branches[selected_branch_index]
      end
    end
  end
  
  puts "--------------------------------------------------------------------------------\n\n\n"

#=== SELECT DEPLOYMENT TARGET ===#

  puts "SELECT DEPLOYMENT TARGET"
  puts "================================================================================"

  puts "Where would you like to deploy to?"
  remotes.each do |remote_name, heroku_app_name|
    puts "(#{remote_name}) #{heroku_app_name}"
  end
  puts ""
  
  selected_remote = nil
  while selected_remote.nil?
    print "Type Remote Name >> "
    selected_remote_input = gets.chomp
    if remotes.has_key? selected_remote_input
      selected_remote = selected_remote_input
    else
      puts "ERROR: You must type the name of the remote exactly as it appears between the " \
        + "parentheses above."
    end
  end

  puts "--------------------------------------------------------------------------------\n\n\n"

#=== DO THE DEPLOYMENT ===#

  puts "EXECUTE DEPLOYMENT"
  puts "================================================================================"

  puts "===> Selected Branch: #{selected_branch}"
  puts "===> Selected Target: #{selected_remote}"
  
  # Ensure that production deployments can only happen from master branch
  if (selected_remote == 'production') && (selected_branch != 'master')
    puts "===> ERROR: Production deployments must be from master branch"
    puts "--------------------------------------------------------------------------------\n\n\n"
    puts "ERROR! Production deployments are only allowed from the master branch. "\
      + "Here are the steps..."
    puts "1) Sync all of your changes up to your Github feature branch"
    puts "2) Do a pull request from your feature branch into master"
    puts "3) Go through the code review process and merge the feature branch into master"
    puts "4) Come back to your local dev environment, checkout master and 'pull origin master'"
    puts "5) Run this script again\n\n"
    exit
  end
  
  # Switch to the selected git branch, do the polymer build
  puts "--------------------------------------------------------------------------------"
  puts "===> REBUILDING POLYMER"
  system("git checkout #{selected_branch}")
  Dir.chdir(polymer_app_path) do
    system("polymer build #{polymer_app_build_options.join(' ')}")
  end
  FileUtils.remove_dir(polymer_app_build_target_path) # clear existing build
  FileUtils.move(polymer_app_build_source_path, polymer_app_build_target_path) # move built files

  # Figure out if the build changed anything and, if so, make sure we're not on master (master doesn't allow git pushes only PRs)
  puts "--------------------------------------------------------------------------------"
  puts "===> COMMITTING REBUILT POLYMER AND PUSHING TO GITHUB"
  uncommitted_changes = `git status --porcelain`
  if uncommitted_changes.empty?
    puts "===> No frontend changes since last build, skipping Github push."
  elsif selected_branch == 'master'
    puts "===> ERROR: Frontend changes need to be pushed to staging first"
    puts "--------------------------------------------------------------------------------\n\n\n"
    puts "ERROR! There were changes to the frontend in this commit cycle."
    puts "You cannot push untested changes directly from the master branch."
    puts "Push to staging first, then do a pull request into master."
    puts "Then after the pull request is merged, come back to your local dev environment,"
    puts "'pull origin master' and retry the deployment.\n\n"
    exit
  else
    # Commit the changes and push them to Github
    system("git add .")
    system("git commit -m '#{POLYMER_REBUILD_COMMIT_MESSAGE}'")
    system("git push origin #{selected_branch}")
  end

  # Deploy to heroku
  puts "--------------------------------------------------------------------------------"
  puts "===> PUSHING BACKEND SUBTREE TO HEROKU..."
  heroku_deploy_command = "git push #{selected_remote} " \
    + "`git subtree split --prefix backend #{selected_branch}`:master --force"
  puts "===> GIT COMMAND ===> #{heroku_deploy_command}"

  system(heroku_deploy_command)
  system("git checkout #{current_branch}") # restore original branch

  puts "--------------------------------------------------------------------------------\n\n\n"


#=== SCRIPT FOOTER ===#

  puts "#===[BADGE LIST #{selected_remote.upcase} DEPLOYMENT COMPLETE]===#\n\n"
