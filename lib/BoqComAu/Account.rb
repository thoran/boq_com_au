# BoqComAu/Account.rb
# BoqComAu::Account

# Notes:
# 1. The login page's ids and names (id4, 8, ...) appear to be generated, so the fields are found by their labels.
# 2. The ids and names after login (id121, 74, ...) appear to be generated too, so TRANSACTIONS_SELECTORS find things by their text.
# 3. BankFast's links are javascript:void(0) where they aren't the session's key and a callback number, and some, such as Transaction History, are in a menu which is closed. A link which isn't displayed is clicked by JavaScript.
# 4. Dropdowns are Chosen's, which hides the select and draws its own: <select id>_chosen, opened by its a.chosen-single and chosen from its li.active-result. A select which is displayed is used as it is.
# 5. Where a one-time code is asked for after logging on, login() waits default_wait_timeout seconds for it to be entered by hand.
# 6. Chrome is started with its automation flags masked; and, given a chrome_profile_directory, with that profile, kept between runs, so as the bank sees a returning browser rather than a fresh automated one. It downloads into download_directory without asking, and opens nothing it downloads.
# 7. A username or password not given stops login, saying which is missing.
# 8. BOQ names the exported file after the account number and the date, as 12345678_20261103.csv, and Chrome numbers a second download of the same name; so the newest CSV file to appear in download_directory once Download is clicked is taken to be it. Chrome names a download in progress .crdownload, so a CSV file is a finished one.
# 9. Dates are BOQ's own, as shown on choosing the account, unless a period or a date is given; then they're set under Advanced Search and searched on before exporting.

require 'date'
require 'webaccount'

module BoqComAu
  class Account < WebAccount
    PAGE_SELECTORS = {
      login_page_url: 'https://www.ib.boq.com.au/boqbl/BankFast-Enterprise-Logon',
      login_page_username_field_selector: {xpath: '//input[@id=//label[normalize-space()="Customer Access Number"]/@for]'},
      login_page_password_field_selector: {xpath: '//input[@id=//label[normalize-space()="Password"]/@for]'},
      login_page_submit_button_selector: {id: 'btnSignIn'},
      logout_button_selector: {xpath: '//a[contains(translate(normalize-space(), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"), "log off")]'},
      logged_out_xpath: '//a[normalize-space()="Log On Again"] | //input[@id="btnSignIn"]'
    }

    TRANSACTIONS_SELECTORS = {
      transaction_history_link: {xpath: '//a[normalize-space()="Transaction History"]'},
      account_select_list: {xpath: '//select[option[contains(., "Select one of the Accounts")]]'},
      advanced_search_link: {xpath: '//a[normalize-space()="Advanced Search"]'},
      text_fields: {xpath: '//input[@type="text"]'},
      search_link: {xpath: '//a[normalize-space()="Search"]'},
      export_all_link: {xpath: '//a[normalize-space()="Export All"]'},
      export_format_select_list: {xpath: '//select[option[contains(., "Comma Delimited Format (CSV)")]]'},
      download_button: {xpath: '//*[self::a or self::button][normalize-space()="Download"] | //input[@value="Download"]'}
    }

    attr_reader :download_directory
    def username
      @username || raise("No username: it's given as username:.")
    end

    def password
      @password || raise("No password: it's given as password:.")
    end

    # period is :all, the last year, or :last_month. Without it, from_date and to_date, either of which defaults to a year ago and today respectively where the other is given. Returns the name of the CSV file downloaded.
    def download_transactions(account_number:, period: nil, from_date: nil, to_date: nil)
      from_date, to_date = dates(period: period, from_date: from_date, to_date: to_date)
      get_transactions_page
      select_bank_account(account_number)
      if from_date
        enter_dates(from_date: from_date, to_date: to_date)
        search
      end
      export_csv
    end

    private

    def initialize(username: nil, password: nil, chrome_profile_directory: nil, download_directory: File.join('~', 'Downloads'), browser: nil, driver_options: nil)
      @chrome_profile_directory = chrome_profile_directory && File.expand_path(chrome_profile_directory)
      @download_directory = File.expand_path(download_directory)
      super(
        username: username, password: password,
        browser: browser, driver_options: driver_options,
        login_page_url: PAGE_SELECTORS[:login_page_url],
        login_page_username_field_selector: PAGE_SELECTORS[:login_page_username_field_selector],
        login_page_password_field_selector: PAGE_SELECTORS[:login_page_password_field_selector],
        login_page_submit_button_selector: PAGE_SELECTORS[:login_page_submit_button_selector],
        logout_button_selector: PAGE_SELECTORS[:logout_button_selector],
        logged_out_xpath: PAGE_SELECTORS[:logged_out_xpath],
      )
    end

    # driver construction

    def default_driver_options
      return unless browser == :chrome
      Selenium::WebDriver::Chrome::Options.new.tap do |o|
        o.add_argument("--user-data-dir=#{@chrome_profile_directory}") if @chrome_profile_directory
        o.add_argument('--disable-blink-features=AutomationControlled')
        o.exclude_switches << 'enable-automation'
        o.add_preference(:credentials_enable_service, false)
        o.add_preference(:download, default_directory: @download_directory, prompt_for_download: false, directory_upgrade: true, extensions_to_open: '')
      end
    end

    # page interaction

    # Found afresh on each attempt, so as an element replaced by a redrawn page is retried rather than ending in StaleElementReferenceError.
    def click(selector)
      driver.attempt do
        element = find(selector)
        element.displayed? ? element.click : driver.execute_script('arguments[0].click();', element)
      end
    end

    def stale?(element)
      element.displayed?
      false
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      true
    end

    def wait_for(selector)
      driver_wait.until{driver.find_elements(*selector.first).any?(&:displayed?)}
    end

    # Dates are set by JavaScript, so as a date picker doesn't open over the fields.
    def set_value(element, value)
      driver.execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('change', {bubbles: true}));", element, value)
    end

    def chosen_list(select_element)
      driver.find_elements(id: "#{select_element.attribute('id')}_chosen").first
    end

    # Yields the text of each option in turn, and chooses the first for which the block is true; nil where there's none. A select hidden by Chosen is waited on until Chosen has drawn its list, which it does after the page has loaded.
    def choose_option(select_element)
      driver_wait.until{select_element.displayed? || chosen_list(select_element)}
      if select_element.displayed?
        option = Selenium::WebDriver::Support::Select.new(select_element).options.detect{|option| yield(option.text)}
      else
        chosen = chosen_list(select_element)
        chosen.find_element(css: 'a.chosen-single').click
        option = chosen.find_elements(css: 'li.active-result').detect{|option| yield(option.text)}
      end
      option&.click
      option
    end

    # dates

    def last_month_start_date
      Date.today.prev_month - (Date.today.prev_month.day - 1)
    end

    def last_month_finish_date
      Date.today - Date.today.day
    end

    # The from and to dates of the period, or of the dates given; nil and nil where neither is given, BOQ's own dates being used.
    def dates(period:, from_date:, to_date:)
      case period
      when :all then [Date.today.prev_year, Date.today]
      when :last_month then [last_month_start_date, last_month_finish_date]
      when nil then (from_date || to_date) ? [from_date || Date.today.prev_year, to_date || Date.today] : [nil, nil]
      else raise ArgumentError, "Unknown period #{period.inspect}: it's :all or :last_month."
      end
    end

    def formatted_date(date)
      date = Date.parse(date) if date.is_a?(String)
      date.strftime('%d/%m/%Y')
    end

    # downloads

    def newest_csv_filename(since:)
      Dir.glob(File.join(@download_directory, '*.csv')).select{|filename| File.mtime(filename) >= since}.max_by{|filename| File.mtime(filename)}
    end

    def wait_for_download(since:)
      driver_wait.until{newest_csv_filename(since: since)}
    end

    # transactions

    def get_transactions_page
      login unless logged_in?
      click(TRANSACTIONS_SELECTORS[:transaction_history_link])
      driver_wait.until{driver.element_present?(*TRANSACTIONS_SELECTORS[:account_select_list].first)}
    end

    def select_bank_account(account_number)
      digits = account_number.to_s.delete('^0-9')
      raise ArgumentError, "No digits in the account number #{account_number.inspect}." if digits.empty?
      unless choose_option(find(TRANSACTIONS_SELECTORS[:account_select_list])){|text| text.delete('^0-9').include?(digits)}
        raise "Can't find account #{account_number} in the account list."
      end
      wait_for(TRANSACTIONS_SELECTORS[:export_all_link])
    end

    # The from and to fields are the two displayed text fields holding a date, as BOQ fills them in. Hidden ones are the form before Advanced Search has redrawn it.
    def date_fields
      driver.find_elements(*TRANSACTIONS_SELECTORS[:text_fields].first).select{|field| field.displayed? && field.attribute('value').to_s.match?(%r{\A\d\d/\d\d/\d{4}\z})}
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      []
    end

    def enter_dates(from_date:, to_date:)
      click(TRANSACTIONS_SELECTORS[:advanced_search_link])
      from_date_field, to_date_field = driver_wait.until{fields = date_fields; fields if fields.size >= 2}
      set_value(from_date_field, formatted_date(from_date))
      set_value(to_date_field, formatted_date(to_date))
      unless [from_date_field, to_date_field].map{|field| field.attribute('value')} == [formatted_date(from_date), formatted_date(to_date)]
        raise "The dates #{formatted_date(from_date)} to #{formatted_date(to_date)} didn't take."
      end
    end

    # Export All is already there before the search, and is replaced when the results are, so the old link is waited out first; otherwise it'd export what was there before.
    def search
      export_all_link = driver.find_elements(*TRANSACTIONS_SELECTORS[:export_all_link].first).first
      click(TRANSACTIONS_SELECTORS[:search_link])
      driver_wait.until{stale?(export_all_link)} if export_all_link
      wait_for(TRANSACTIONS_SELECTORS[:export_all_link])
    end

    def export_csv
      click(TRANSACTIONS_SELECTORS[:export_all_link])
      driver_wait.until{driver.element_present?(*TRANSACTIONS_SELECTORS[:export_format_select_list].first)}
      unless choose_option(find(TRANSACTIONS_SELECTORS[:export_format_select_list])){|text| text.include?('(CSV)')}
        raise "Can't find the CSV export format."
      end
      clicked_at = Time.now
      click(TRANSACTIONS_SELECTORS[:download_button])
      wait_for_download(since: clicked_at)
    end
  end
end
