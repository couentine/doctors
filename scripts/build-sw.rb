#==========================================================================================================================================#
#  
#  BUILD SERVICE WORKER
#  
#  This is a simple script which calls the node command that rebuilds the service worker.
#  
#==========================================================================================================================================#


puts "\n\n"
puts "================================================================================"
puts "REBUILDING SERVICE WORKER"
puts "================================================================================"

# Get the path
root_path = `git rev-parse --show-toplevel`.chomp
service_worker_path = "#{root_path}/frontend/bl-service-worker"

Dir.chdir(service_worker_path) do
  system('npm run build')
end

puts "\n\n"
