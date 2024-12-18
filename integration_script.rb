require 'watir'
require 'securerandom'
require 'csv'
require 'logger'

LOGGER = Logger.new($stdout)
LOGGER.level = Logger::INFO

BROWSER_OPTIONS = {
  headless: false,
  options: {
    prefs: {
      download: {
        prompt_for_download: false,
        default_directory: "#{Dir.pwd}/data"
      }
    }
  }
}.freeze

BADGE_IDS = %w[deletedBadge erroredBadge warningBadge].freeze

def run_integration_and_report
  run_id = SecureRandom.uuid
  start_time = Time.now.utc.iso8601

  LOGGER.info "============================================================"
  LOGGER.info "[INFO] Integration Run Started"
  LOGGER.info "[INFO] Timestamp: #{start_time}"
  LOGGER.info "[INFO] Generated Run ID: #{run_id}"
  LOGGER.info "============================================================"

  browser = setup_browser
  LOGGER.info "[INFO] Browser launched."

  begin
    login_to_application(browser)

    LOGGER.info "[INFO] Navigating to the integrations page..."
    browser.link(href: '/integrations').click

    run_integration(browser, run_id)
    handle_post_run_actions(browser, run_id)

  rescue Watir::Wait::TimeoutError
    LOGGER.error "[ERROR] Run #{run_id} timed out waiting for completion."
    write_run_details_to_csv(run_id, "TIMEOUT", 0, [], Time.now.utc.iso8601)
  ensure
    browser.close
    LOGGER.info "[INFO] Browser closed. Integration run finished."
  end
end

def run_report_on_existing_integration
  run_id = "22ac63a9-3a9e-4801-806d-c19c2d4d254c"
  LOGGER.info "============================================================"
  LOGGER.info "[INFO] Testing CSV logic for existing Run ID: #{run_id}"
  LOGGER.info "============================================================"

  browser = setup_browser
  LOGGER.info "[INFO] Browser launched."

  begin
    login_to_application(browser)

    LOGGER.info "[INFO] Searching for the existing Run ID: #{run_id}..."
    browser.text_field(id: 'name').set(run_id)

    search_result = browser.link(text: /#{run_id}/)
    browser.wait_until(timeout: 20) { search_result.present? }

    LOGGER.info "[INFO] Clicking the search result for Run ID: #{run_id}..."
    search_result.click

    handle_post_run_actions(browser, run_id)

  rescue Watir::Wait::TimeoutError
    LOGGER.error "[ERROR] Run #{run_id} timed out waiting for completion."
    write_run_details_to_csv(run_id, "TIMEOUT", 0, [], Time.now.utc.iso8601)
  ensure
    browser.close
    LOGGER.info "[INFO] Browser closed. Integration run finished."
  end
end

def setup_browser
  Watir::Browser.new(:chrome, **BROWSER_OPTIONS)
end

def login_to_application(browser)
  LOGGER.info "[INFO] Navigating to the login page..."
  browser.goto 'https://demo-dimension.calance.us'

  LOGGER.info "[INFO] Attempting to log in..."
  browser.text_field(id: 'user_id').set('test_2024')
  browser.text_field(id: 'password').set('Test$12345')

  login_button = browser.button(text: 'Sign in with Dimension')
  browser.wait_until(timeout: 15) { login_button.enabled? }
  login_button.click
end

def run_integration(browser, run_id)
  LOGGER.info "[INFO] Running 'Take a while and do things' integration..."
  browser.text_field(placeholder: 'My Identifier').set(run_id)

  run_integration_button = browser.button(id: 'runLiveBtn-0')
  browser.wait_until(timeout: 15) { run_integration_button.enabled? }
  run_integration_button.click

  run_id_link = browser.link(text: /#{run_id}/)
  browser.wait_until(timeout: 20) { run_id_link.present? }
  run_id_link.click
end

def handle_post_run_actions(browser, run_id)
  LOGGER.info "[INFO] Waiting for the Run Details status to update to 'Errored' or 'Complete'..."
  status_header = browser.h3(class: 'RunDetails_statusHeader__GhXHG')
  browser.wait_until(timeout: 300) do
    status_text = status_header.text
    status_text.include?('Errored') || status_text.include?('Complete')
  end

  LOGGER.info "[INFO] Run status confirmed. Performing post-run actions..."

  total_actions = extract_total_actions(browser)
  toggle_filters(browser)
  export_and_process_csv(browser, run_id, status_header.text, total_actions)
  print_latest_run_details
end

def extract_total_actions(browser)
  pagination_info = browser.div(text: /Showing items/).text
  total_actions = pagination_info.match(/of (\d+)/)[1].to_i
  LOGGER.info "[INFO] Total actions: #{total_actions}"
  total_actions
end

def toggle_filters(browser)
  BADGE_IDS.each do |badge_id|
    filter = browser.span(id: badge_id)
    if filter.present?
      filter.click
      LOGGER.info "[INFO] Toggled filter: #{badge_id}"
    end
  end
end

def export_and_process_csv(browser, run_id, status, total_actions)
  LOGGER.info "[INFO] Exporting CSV data..."
  export_button = browser.button(class: /ExportCsv_exportBtn__2UjzH/)
  export_button.click if export_button.present?
  sleep 5

  csv_file_path = "#{Dir.pwd}/data/data.csv"
  begin
    LOGGER.info "[INFO] Processing exported CSV data..."
    extracted_data = extract_data_from_csv(csv_file_path)
    write_run_details_to_csv(run_id, status, total_actions, extracted_data, Time.now.utc.iso8601)
  ensure
    delete_temp_csv(csv_file_path)
  end
end

def extract_data_from_csv(file)
  things = []
  CSV.foreach(file, headers: true) do |row|
    # Combine all lines in the description if it's multi-line
    description = row['Description']&.gsub(/\n/, ' ') || ''
    next unless description.include?('Thing:') # Skip rows without "Thing:"

    # Extract Thing ID using a regex
    thing_match = description.match(/Thing:\s*(\d+)/)
    if thing_match
      thing_id = thing_match[1]
      things << { name: "Thing #{thing_id}", id: thing_id }
    end
  end
  things
end

def delete_temp_csv(file_path)
  if File.exist?(file_path)
    File.delete(file_path)
    LOGGER.info "[INFO] Temporary CSV file #{file_path} deleted."
  else
    LOGGER.warn "[WARN] Temporary CSV file #{file_path} not found."
  end
end

def write_run_details_to_csv(run_id, status, actions, things, start_time)
  csv_file = 'run_history.csv'
  new_file = !File.exist?(csv_file)

  CSV.open(csv_file, 'a') do |csv|
    csv << ["timestamp", "run_id", "status", "actions", "things"] if new_file
    csv << [start_time, run_id, status, actions, things.to_json]
  end
  LOGGER.info "[INFO] Run details written to #{csv_file}."
end

def print_latest_run_details
  csv_file = 'run_history.csv'

  # Read the CSV and fetch the last row as an array of strings
  latest_run_row = CSV.read(csv_file, headers: true).to_a.last

  if latest_run_row
    # Convert the last row back to a hash using the headers
    headers = CSV.read(csv_file, headers: true).headers
    latest_run = Hash[headers.zip(latest_run_row)]

    # Parse "Things" from JSON
    things = JSON.parse(latest_run['things'])

    LOGGER.info "[INFO] Latest Run Details:"
    puts "\n=== Latest Run Details ==="
    puts "Timestamp:  #{latest_run['timestamp']}"
    puts "Run ID:     #{latest_run['run_id']}"
    puts "Status:     #{latest_run['status']}"
    puts "Actions:    #{latest_run['actions']}"
    puts "Data:"
    things.each_with_index do |thing, index|
      puts "  #{index + 1}. #{thing['name']} (ID: #{thing['id']})"
    end
    puts "===========================\n"
  else
    LOGGER.warn "[WARN] No runs found in run_history.csv."
    puts "\nNo runs found in run_history.csv.\n"
  end
end

run_report_on_existing_integration