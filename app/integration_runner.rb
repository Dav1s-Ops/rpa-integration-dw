require 'watir'
require 'securerandom'
require 'csv'
require 'logger'
require 'json'
require 'webdrivers'

class IntegrationRunner
  BROWSER_OPTIONS = {
    headless: true,
    options: {
      prefs: {
        download: {
          prompt_for_download: false,
          default_directory: File.join(Dir.pwd, 'data')
        }
      },
      args: ['--headless', '--disable-gpu', '--no-sandbox', '--disable-dev-shm-usage', '--window-size=1920,1080']
    }
  }.freeze

  BADGE_IDS = %w[deletedBadge erroredBadge warningBadge].freeze

  def initialize(logger: Logger.new($stdout), base_url: 'https://demo-dimension.calance.us')
    @logger = logger
    @logger.level = Logger::INFO
    @base_url = base_url
    @logged_actions = Set.new
  end

  def run_integration_and_report
    run_id = SecureRandom.uuid
    start_time = Time.now.utc.iso8601

    log_info("============================================================")
    log_info("[INFO] Integration Run Started")
    log_info("[INFO] Timestamp: #{start_time}")
    log_info("[INFO] Generated Run ID: #{run_id}")
    log_info("============================================================")

    browser = setup_browser
    log_info("[INFO] Browser launched.")

    begin
      login_to_application(browser)
      log_info("[INFO] Navigating to the integrations page...")
      browser.link(href: '/integrations').click

      run_integration(browser, run_id)
      handle_post_run_actions(browser, run_id)
    rescue Watir::Wait::TimeoutError
      @logger.error("[ERROR] Run #{run_id} timed out waiting for completion.")
      write_run_details_to_csv(run_id, "TIMEOUT", 0, [], Time.now.utc.iso8601)
    ensure
      browser.close
      log_info("[INFO] Browser closed. Integration run finished.")
    end
  end

  def run_report_on_existing_integration(run_id)
    log_info("============================================================")
    log_info("[INFO] Running report for existing Run ID: #{run_id}")
    log_info("============================================================")

    browser = setup_browser
    log_info("[INFO] Browser launched.")

    begin
      login_to_application(browser)
      log_info("[INFO] Searching for the existing Run ID: #{run_id}...")
      browser.text_field(id: 'name').set(run_id)

      search_result = browser.link(text: /#{run_id}/)
      browser.wait_until(timeout: 20) { search_result.present? }

      log_info("[INFO] Clicking the search result for Run ID: #{run_id}...")
      search_result.click

      handle_post_run_actions(browser, run_id)
    rescue Watir::Wait::TimeoutError
      @logger.error("[ERROR] Run #{run_id} timed out waiting for completion.")
      write_run_details_to_csv(run_id, "TIMEOUT", 0, [], Time.now.utc.iso8601)
    ensure
      browser.close
      log_info("[INFO] Browser closed. Report run finished.")
    end
  end

  private

  def setup_browser
    Watir::Browser.new(:chrome, **BROWSER_OPTIONS)
  end

  def login_to_application(browser)
    log_info("[INFO] Navigating to the login page...")
    browser.goto @base_url

    log_info("[INFO] Attempting to log in...")
    browser.text_field(id: 'user_id').set('test_2024')
    browser.text_field(id: 'password').set('Test$12345')

    login_button = browser.button(text: 'Sign in with Dimension')
    browser.wait_until(timeout: 15) { login_button.enabled? }
    login_button.click
  end

  def run_integration(browser, run_id)
    log_info("[INFO] Running 'Take a while and do things' integration...")
    browser.text_field(placeholder: 'My Identifier').set(run_id)

    run_integration_button = browser.button(id: 'runLiveBtn-0')
    browser.wait_until(timeout: 15) { run_integration_button.enabled? }
    run_integration_button.click

    run_id_link = browser.link(text: /#{run_id}/)
    browser.wait_until(timeout: 20) { run_id_link.present? }
    run_id_link.click
  end

  def handle_post_run_actions(browser, run_id)
    log_info("[INFO] Setting page size to 250...")
    set_page_size(browser, 250)
    
    log_info("[INFO] Waiting for the Run Details status to update to 'Errored' or 'Complete'...")
    status_header = browser.h3(class: 'RunDetails_statusHeader__GhXHG')
    
    start_time = Time.now
    loop do
      break if Time.now - start_time > 300
      status_text = status_header.text
      log_table_data(browser)
      
      if status_text.include?('Errored') || status_text.include?('Complete')
        log_info("[INFO] Run status confirmed: #{status_text}")
        break
      end
      
      sleep 1
    end
    
    total_actions = extract_total_actions(browser)
    toggle_filters(browser)
    export_and_process_csv(browser, run_id, status_header.text, total_actions)
    print_latest_run_details
  end
  

  def set_page_size(browser, size)
    log_info("[INFO] Setting table page size to #{size}...")
    page_size_select = browser.select(xpath: "//select[contains(@style, 'width: 50px')]")
    page_size_select.select(size.to_s)
    browser.wait_until { browser.table(id: 'reactTable').exists? }
    log_info("[INFO] Page size set to #{size}.")
  end
  
  
  def log_table_data(browser)
    table_rows = browser.table(id: 'reactTable').tbody.trs
    table_rows.each do |row|
      time = row.td(index: 0).text
      type = row.td(index: 1).text
      description = row.td(index: 2).text
  
      action_key = "#{time}-#{description}"
  
      unless @logged_actions.include?(action_key)
        @logged_actions.add(action_key)
        log_info("[ACTION] Type: #{type}, Description: #{description}")
      end
    end
  end
  

  def extract_total_actions(browser)
    pagination_info = browser.div(text: /Showing items/).text
    total_actions = pagination_info.match(/of (\d+)/)[1].to_i
    log_info("[INFO] Total actions: #{total_actions}")
    total_actions
  end

  def toggle_filters(browser)
    BADGE_IDS.each do |badge_id|
      filter = browser.span(id: badge_id)
      if filter.present?
        filter.click
        formatted_name = badge_id.gsub(/Badge$/, '').capitalize
        log_info("[INFO] Toggled filter: #{formatted_name}")
      end
    end
  end
  

  def export_and_process_csv(browser, run_id, status, total_actions)
    log_info("[INFO] Exporting CSV data...")
    export_button = browser.button(class: /ExportCsv_exportBtn__2UjzH/)
    export_button.click if export_button.present?
    sleep 5

    csv_file_path = File.join(Dir.pwd, 'data', 'data.csv')
    begin
      log_info("[INFO] Processing exported CSV data...")
      extracted_data = extract_data_from_csv(csv_file_path)
      write_run_details_to_csv(run_id, status, total_actions, extracted_data, Time.now.utc.iso8601)
    ensure
      delete_temp_csv(csv_file_path)
    end
  end

  def extract_data_from_csv(file)
    things = []
    CSV.foreach(file, headers: true) do |row|
      description = row['Description']&.gsub(/\n/, ' ') || '' # combine all lines in the description
      next unless description.include?('Thing:')

      thing_match = description.match(/Thing:\s*(\d+)/) # extract Thing & ID using a regex
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
      log_info("[INFO] Temporary CSV file #{file_path} deleted.")
    else
      @logger.warn("[WARN] Temporary CSV file #{file_path} not found.")
    end
  end

  def write_run_details_to_csv(run_id, status, actions, things, start_time)
    csv_file = 'run_history.csv'
    new_file = !File.exist?(csv_file)

    CSV.open(csv_file, 'a') do |csv|
      csv << ["timestamp", "run_id", "status", "actions", "things"] if new_file
      csv << [start_time, run_id, status, actions, things.to_json]
    end
    log_info("[INFO] Run details written to #{csv_file}.")
  end

  def print_latest_run_details
    csv_file = 'run_history.csv'

    latest_run_row = CSV.read(csv_file, headers: true).to_a.last # get last row as array of strings

    if latest_run_row
      headers = CSV.read(csv_file, headers: true).headers # convert headers to array of strings
      latest_run = Hash[headers.zip(latest_run_row)] # zip header and data array together as tuple & convert to object

      things = JSON.parse(latest_run['things']) # parse the Things json to an object

      log_info("[INFO] Latest Run Details:")
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
      @logger.warn("[WARN] No runs found in run_history.csv.")
      puts "\nNo runs found in run_history.csv.\n"
    end
  end

  def log_info(message)
    @logger.info(message)
  end
end
