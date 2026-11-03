# BoqComAu/Account.rb
# BoqComAu::Account

# Notes:
# 1. The login page's ids and names (id4, 8, ...) appear to be generated, so the fields are found by their labels.
# 2. Where a one-time code is asked for after logging on, login() waits default_wait_timeout seconds for it to be entered by hand.
# 3. Chrome is started with its automation flags masked; and, given a chrome_profile_directory, with that profile, kept between runs, so as the bank sees a returning browser rather than a fresh automated one.
# 4. A username or password not given stops login, saying which is missing.

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

    def username
      @username || raise("No username: it's given as username:.")
    end

    def password
      @password || raise("No password: it's given as password:.")
    end

    def login(username: nil, password: nil)
      @logged_in = false
      username ||= self.username
      password ||= self.password
      driver.attempt do
        get_login_page
        enter_username(username)
        enter_password(password)
        login_page_submit_button.click
      end
      @logged_in = driver_wait.until{!driver.element_present?(:id, 'btnSignIn')}
    end
    alias_method :logon, :login

    # Chrome is quit whether or not logging out succeeds, so as a failed logout doesn't leave a logged-in browser behind.
    def shutdown
      logout if logged_in?
    ensure
      driver.quit
    end

    private

    def initialize(username: nil, password: nil, chrome_profile_directory: nil, browser: nil, driver_options: nil)
      @chrome_profile_directory = chrome_profile_directory && File.expand_path(chrome_profile_directory)
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
      end
    end
  end
end
