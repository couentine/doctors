#==========================================================================================================================================#
#  
#  BUILD POLYMER
#  
#  This builds the polymer front end apps (both app and website) and copies them to `/backend/public/p`.
#  
#==========================================================================================================================================#

require 'fileutils'

#=== CONSTANTS ===#

  # If you need to manually build here is a version to copy and paste:
  # polymer build --js-minify --css-minify --html-minify --bundle --add-service-worker --insert-prefetch-links
  polymer_build_options = [
    '--js-minify',
    '--css-minify',
    '--html-minify',
    '--bundle',
    '--insert-prefetch-links'
  ]

  # This should be a list of all of the polymer "apps". Each one should correspond to a source directory in `/frontend`.
  polymer_app_list = ['app', 'website']

#=== INITIALIZATION ===#
  
  puts ""
  puts "--------------------------------------------------------------------------------"
  puts "===> REBUILDING POLYMER FRONTEND"
  puts ""

  # Get the various paths
  root_path = `git rev-parse --show-toplevel`.chomp
  frontend_root = "#{root_path}/frontend"
  build_destination = "#{root_path}/backend/public/p"
  puts "===> Root path: #{root_path}"
  puts "===> Frontend root: #{frontend_root}"
  puts "===> Build destination root: #{build_destination}"

  puts "--------------------------------------------------------------------------------"

#=== BUILD PROCESS ===#

  polymer_app_list.each do |app_key|
    current_root = "#{frontend_root}/#{app_key}" 
    source_path = "#{current_root}/build/default"
    target_path = "#{build_destination}/#{app_key}"
    puts "===> Building '#{app_key}'..."
    puts "===> Current root: #{current_root}"
    puts "===> Build source path: #{source_path}"
    puts "===> Build destination path: #{target_path}"
    
    Dir.chdir(current_root) do
      system("polymer build #{polymer_build_options.join(' ')}")
    end
    begin
      FileUtils.remove_dir(target_path) # clear existing build
    rescue Exception => e
      puts "ERROR removing target path (#{target_path}), continuing..."
    end
    FileUtils.move(source_path, target_path) # move built files
    
    puts "--------------------------------------------------------------------------------"
  end

puts "===> POLYMER FRONTEND REBUILD COMPLETE!"
puts "--------------------------------------------------------------------------------"
puts ""