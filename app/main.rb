require_relative 'integration_runner'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby main.rb [--run | --report <UUID>]"

  opts.on("--run", "Run a new integration") do
    options[:run] = true
  end

  opts.on("--report UUID", "Report on an existing integration run") do |uuid|
    options[:report] = uuid
  end
end.parse!

runner = IntegrationRunner.new

if options[:run]
  runner.run_integration_and_report
elsif options[:report]
  runner.run_report_on_existing_integration(options[:report])
else
  puts "No valid options provided. Use --run to start a new integration or --report <UUID> to report on an existing run."
  exit 1
end
