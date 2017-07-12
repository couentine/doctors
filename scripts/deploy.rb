#=== CONSTANTS ===#

remotes = { # first is default
  'staging' => 'bl-staging-mango', 
  'production' => 'badgelist'
}

#=== SCRIPT BANNER ===#

  puts "\n\n#===[BADGE LIST DEPLOYMENT SCRIPT]===#\n\n\n"

#=== CHECK GIT CONFIGURATION ===#

  puts "LOAD GIT CONFIGURATION"
  puts "=================================================="

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
  untracked_files = `git status --porcelain`
  if !untracked_files.empty?
    puts "===> ERROR: Uncommitted changes found...\n#{untracked_files}"
    puts "--------------------------------------------------\n\n\n"
    puts "ERROR! You have uncommitted changes in your local git environment."
    puts "Please make sure all files are committed before continuing.\n\n"
    exit
  end

  puts "--------------------------------------------------\n\n\n"


#=== SELECT LOCAL BRANCH ===#

  puts "SELECT BRANCH TO DEPLOY"
  puts "=================================================="

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
  
  puts "--------------------------------------------------\n\n\n"

#=== SELECT DEPLOYMENT TARGET ===#

  puts "SELECT DEPLOYMENT TARGET"
  puts "=================================================="

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

  puts "--------------------------------------------------\n\n\n"

#=== DO THE DEPLOYMENT ===#

  git_command = "git push #{selected_remote} " \
    + "`git subtree split --prefix backend #{selected_branch}`:master --force"

  puts "EXECUTE DEPLOYMENT"
  puts "=================================================="

  puts "===> Selected Branch: #{selected_branch}"
  puts "===> Selected Target: #{selected_remote}"
  puts "===> PUSHING BACKEND SUBTREE TO HEROKU..."
  puts "===> GIT COMMAND ===> #{git_command}"

  system(git_command)

  puts "--------------------------------------------------\n\n\n"


#=== SCRIPT FOOTER ===#

  puts "#===[BADGE LIST #{selected_remote.upcase} DEPLOYMENT COMPLETE]===#\n\n"
