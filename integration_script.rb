require 'watir'
require 'webdrivers'

trap("INT") do
  puts "\nGracefully exiting... (•‿•)"
  exit
end

def run_integration_and_report
  loop do
    puts "hello world!"
    sleep 10
  end
end

run_integration_and_report