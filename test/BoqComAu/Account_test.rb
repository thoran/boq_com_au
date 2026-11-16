# test/BoqComAu/Account_test.rb

# Notes:
# 1. No browser and no BOQ: only what doesn't depend on the site is tested. Every account which might reach for its browser is given a stand-in, so as none is started.

require_relative '../../lib/boq_com_au'

require 'date'
require 'minitest/autorun'
require 'minitest-spec-context'

describe BoqComAu::Account do
  def stand_in_element(text: '', displayed: true, id: nil)
    element = Object.new
    element.define_singleton_method(:text){text}
    element.define_singleton_method(:displayed?){displayed}
    element.define_singleton_method(:attribute){|name| id if name == 'id'}
    element.define_singleton_method(:click){@clicked = true}
    element.define_singleton_method(:clicked?){!!@clicked}
    element
  end

  # What Chosen draws for a hidden select: <select id>_chosen, with a.chosen-single to open it and li.active-result to choose from.
  def stand_in_chosen(*texts)
    opener = stand_in_element
    options = texts.map{|text| stand_in_element(text: text)}
    chosen = Object.new
    chosen.define_singleton_method(:find_element){|*| opener}
    chosen.define_singleton_method(:find_elements){|*| options}
    [chosen, opener, options]
  end

  # Goes stale, as a link does when the page redraws it, once stale! is called.
  def stand_in_link
    link = stand_in_element
    link.define_singleton_method(:stale!){@stale = true}
    link.define_singleton_method(:displayed?){@stale ? raise(Selenium::WebDriver::Error::StaleElementReferenceError) : true}
    link
  end

  # Finds the elements by id given, and otherwise those given in elements; though only after the number of looks given in drawn_after, as for a list Chosen hasn't drawn yet.
  def stand_in_driver(elements_by_id: {}, elements: [], drawn_after: 0)
    driver = Object.new
    looks = 0
    driver.define_singleton_method(:attempt){|&block| block.call(self)}
    driver.define_singleton_method(:find_elements){|*, **by| (looks += 1) > drawn_after ? (by[:id] ? [elements_by_id[by[:id]]].compact : elements) : []}
    driver.define_singleton_method(:element_present?){|*| true}
    driver.define_singleton_method(:execute_script){|script, *args| (@scripts ||= []) << [script, *args]}
    driver.define_singleton_method(:scripts){@scripts || []}
    driver
  end

  def account_with_driver(driver, **args)
    account = BoqComAu::Account.new(**args)
    account.instance_variable_set(:@driver, driver)
    account.instance_variable_set(:@logged_in, true)
    account
  end

  # An account whose account list is a hidden select drawn by Chosen, as BOQ's is.
  def account_with_accounts(*texts, drawn_after: 0)
    chosen, opener, options = stand_in_chosen(*texts)
    select_list = stand_in_element(displayed: false, id: 'id71')
    account = account_with_driver(stand_in_driver(elements_by_id: {'id71_chosen' => chosen}, drawn_after: drawn_after))
    account.define_singleton_method(:find){|*| select_list}
    account.define_singleton_method(:wait_for){|*| true}
    [account, opener, options]
  end

  describe "#username and #password" do
    it "are those given" do
      account = BoqComAu::Account.new(username: 'customer', password: 'secret')
      _(account.username).must_equal('customer')
      _(account.password).must_equal('secret')
    end

    it "can be set after construction" do
      account = BoqComAu::Account.new
      account.username, account.password = 'customer', 'secret'
      _(account.username).must_equal('customer')
      _(account.password).must_equal('secret')
    end

    it "are nil where they're not given, rather than read from the environment" do
      ENV['BOQ_USERNAME'], ENV['BOQ_PASSWORD'] = 'customer', 'secret'
      account = BoqComAu::Account.new
      _(account.username).must_be_nil
      _(account.password).must_be_nil
    ensure
      ENV.delete('BOQ_USERNAME')
      ENV.delete('BOQ_PASSWORD')
    end
  end

  describe "#login" do
    it "names the one missing, before starting the browser" do
      account = BoqComAu::Account.new(username: 'customer')
      _(_{account.login}.must_raise(ArgumentError).message).must_equal('password is missing.')
      _(account.instance_variable_get(:@driver)).must_be_nil
    end

    it "names both where both are missing" do
      _(_{BoqComAu::Account.new.login}.must_raise(ArgumentError).message).must_equal('username, password are missing.')
    end

    it "takes either given to login itself as given" do
      _(_{BoqComAu::Account.new(username: 'customer').login(password: nil)}.must_raise(ArgumentError).message).must_equal('password is missing.')
      _(_{BoqComAu::Account.new.login(username: 'customer')}.must_raise(ArgumentError).message).must_equal('password is missing.')
    end
  end

  describe "#download_transactions" do
    def account_recording_steps
      account = account_with_driver(stand_in_driver)
      steps = []
      %i{get_transactions_page select_bank_account search export_csv}.each{|step| account.define_singleton_method(step){|*| steps << step}}
      account.define_singleton_method(:enter_dates){|from_date:, to_date:| steps << [:enter_dates, from_date, to_date]}
      account.define_singleton_method(:transactions?){@transactions != false}
      [account, steps]
    end

    it "uses BOQ's own dates where neither a period nor a date is given" do
      account, steps = account_recording_steps
      account.download_transactions(account_number: '12345678')
      _(steps).must_equal(%i{get_transactions_page select_bank_account export_csv})
    end

    it "sets the dates and searches on them before exporting where they're given" do
      account, steps = account_recording_steps
      account.download_transactions(account_number: '12345678', from_date: '2026-10-01', to_date: '2026-10-31')
      _(steps).must_equal([:get_transactions_page, :select_bank_account, [:enter_dates, '2026-10-01', '2026-10-31'], :search, :export_csv])
    end

    it "exports nothing, and returns nil, where there are no transactions" do
      account, steps = account_recording_steps
      account.instance_variable_set(:@transactions, false)
      _(account.download_transactions(account_number: '12345678', period: :last_month)).must_be_nil
      _(steps).must_equal([:get_transactions_page, :select_bank_account, [:enter_dates, *account.send(:dates, period: :last_month, from_date: nil, to_date: nil)], :search])
    end

    it "names a missing account number, before going to the transactions page" do
      account, steps = account_recording_steps
      _(_{account.download_transactions(account_number: nil)}.must_raise(ArgumentError).message).must_equal('account_number is missing.')
      _(steps).must_be_empty
    end
  end

  describe "the browser" do
    it "is Chrome, started with the profile given, expanded, downloading into the download directory given" do
      options = BoqComAu::Account.new(profile_directory: '~/profiles/boq', download_directory: '~/statements').send(:default_driver_options)
      _(options).must_be_kind_of(Selenium::WebDriver::Chrome::Options)
      _(options.args).must_include("--user-data-dir=#{File.expand_path('~/profiles/boq')}")
      _(options.prefs[:download][:default_directory]).must_equal(File.expand_path('~/statements'))
    end

    it "is Firefox where asked for, started with the profile given, downloading into the download directory given" do
      options = BoqComAu::Account.new(browser: :firefox, profile_directory: '~/profiles/boq', download_directory: '~/statements').send(:default_driver_options)
      _(options).must_be_kind_of(Selenium::WebDriver::Firefox::Options)
      _(options.args).must_equal(['-profile', File.expand_path('~/profiles/boq')])
      _(options.prefs['browser.download.dir']).must_equal(File.expand_path('~/statements'))
    end

    it "downloads into ~/Downloads where no directory is given" do
      _(BoqComAu::Account.new.download_directory).must_equal(File.expand_path('~/Downloads'))
    end

    it "takes the profile as profile_directory:, no longer as chrome_profile_directory:" do
      _{BoqComAu::Account.new(chrome_profile_directory: '~/profiles/boq')}.must_raise(ArgumentError)
    end

    it "uses BOQ's selectors where none is given" do
      account = BoqComAu::Account.new
      _(account.send(:login_page_username_field_selector)).must_equal(BoqComAu::Account::PAGE_SELECTORS[:login_page_username_field_selector])
      _(account.send(:logout_button_selector)).must_equal(BoqComAu::Account::PAGE_SELECTORS[:logout_button_selector])
      _(account.logged_out_selector).must_equal({xpath: '//a[normalize-space()="Log On Again"] | //input[@id="btnSignIn"]'})
    end

    it "uses a selector set after construction over BOQ's" do
      account = BoqComAu::Account.new
      account.logged_out_selector = {id: 'btnLogOn'}
      _(account.logged_out_selector).must_equal({id: 'btnLogOn'})
    end

    it "logs in where told to, a keyword winning over BOQ's selector" do
      account = BoqComAu::Account.new(login_page_url: 'https://test.example.com/logon', logout_button_selector: {id: 'logoff'})
      _(account.send(:login_page_url)).must_equal('https://test.example.com/logon')
      _(account.send(:logout_button_selector)).must_equal({id: 'logoff'})
      _(account.send(:login_page_username_field_selector)).must_equal(BoqComAu::Account::PAGE_SELECTORS[:login_page_username_field_selector])
    end
  end

  describe "#dates" do
    def dates(**args)
      BoqComAu::Account.new.send(:dates, **{period: nil, from_date: nil, to_date: nil}.merge(args))
    end

    it "is the last year for :all" do
      _(dates(period: :all)).must_equal([Date.today.prev_year, Date.today])
    end

    it "is last month for :last_month" do
      today = Date.today
      _(dates(period: :last_month)).must_equal([Date.new(today.prev_month.year, today.prev_month.month, 1), Date.new(today.year, today.month, 1) - 1])
    end

    it "is the dates given, defaulting the other to a year ago or today" do
      _(dates(from_date: '2026-01-01', to_date: '2026-02-01')).must_equal(['2026-01-01', '2026-02-01'])
      _(dates(from_date: '2026-01-01')).must_equal(['2026-01-01', Date.today])
      _(dates(to_date: '2026-02-01')).must_equal([Date.today.prev_year, '2026-02-01'])
    end

    it "is none where neither a period nor a date is given" do
      _(dates).must_equal([nil, nil])
    end

    it "refuses a period it doesn't know" do
      _{dates(period: :fortnight)}.must_raise(ArgumentError)
    end
  end

  describe "#formatted_date" do
    it "is day/month/year, from a Date or a String" do
      account = BoqComAu::Account.new
      _(account.send(:formatted_date, Date.new(2026, 3, 4))).must_equal('04/03/2026')
      _(account.send(:formatted_date, '2026-03-04')).must_equal('04/03/2026')
    end
  end

  describe "#get_transactions_page" do
    it "clicks the history link by JavaScript, the link being in a menu which is closed" do
      driver = stand_in_driver
      link = stand_in_element(displayed: false)
      account = account_with_driver(driver)
      account.define_singleton_method(:find){|*| link}
      account.send(:get_transactions_page)
      _(driver.scripts).must_equal([['arguments[0].click();', link]])
      _(link.clicked?).must_equal(false)
    end
  end

  describe "#select_bank_account" do
    it "opens the account list and picks the account by the digits of its number, however either is written" do
      account, opener, options = account_with_accounts('Everyday 1111 2222', 'Saver 3333-4444')
      account.send(:select_bank_account, '33334444')
      _(opener.clicked?).must_equal(true)
      _(options.map(&:clicked?)).must_equal([false, true])
    end

    it "waits for Chosen to draw the list where it hasn't yet" do
      account, opener, options = account_with_accounts('Everyday 1111 2222', drawn_after: 2)
      account.send(:select_bank_account, '11112222')
      _(opener.clicked?).must_equal(true)
      _(options.map(&:clicked?)).must_equal([true])
    end

    it "says which account it couldn't find" do
      account, _opener, _options = account_with_accounts('Everyday 1111 2222')
      error = _{account.send(:select_bank_account, '9999')}.must_raise(RuntimeError)
      _(error.message).must_include('9999')
    end

    it "refuses an account number without digits, which would match every account" do
      account, _opener, options = account_with_accounts('Everyday 1111 2222')
      _{account.send(:select_bank_account, '...')}.must_raise(ArgumentError)
      _(options.map(&:clicked?)).must_equal([false])
    end
  end

  describe "#enter_dates" do
    def stand_in_date_field(value, displayed: true)
      field = Object.new
      field.instance_variable_set(:@value, value)
      field.define_singleton_method(:displayed?){displayed}
      field.define_singleton_method(:attribute){|name| @value if name == 'value'}
      field.define_singleton_method(:value=){|value| @value = value}
      field
    end

    # A driver whose set_value() sets the field, or, where the page throws the value away, doesn't.
    def account_with_date_fields(fields, taking: true)
      driver = stand_in_driver(elements: fields)
      driver.define_singleton_method(:execute_script){|script, element = nil, value = nil| element.value = value if taking && element.respond_to?(:value=)}
      account = account_with_driver(driver)
      account.define_singleton_method(:click){|*| true}
      account
    end

    it "sets the displayed date fields, leaving the hidden ones of the form before it was redrawn" do
      hidden_from, hidden_to = stand_in_date_field('28/10/2026', displayed: false), stand_in_date_field('03/11/2026', displayed: false)
      from, to = stand_in_date_field('28/10/2026'), stand_in_date_field('03/11/2026')
      account = account_with_date_fields([hidden_from, hidden_to, from, to])
      account.send(:enter_dates, from_date: Date.new(2026, 10, 1), to_date: Date.new(2026, 10, 31))
      _([from, to].map{|field| field.attribute('value')}).must_equal(['01/10/2026', '31/10/2026'])
      _([hidden_from, hidden_to].map{|field| field.attribute('value')}).must_equal(['28/10/2026', '03/11/2026'])
    end

    it "says so where the dates didn't take, rather than searching another range" do
      account = account_with_date_fields([stand_in_date_field('28/10/2026'), stand_in_date_field('03/11/2026')], taking: false)
      error = _{account.send(:enter_dates, from_date: Date.new(2026, 10, 1), to_date: Date.new(2026, 10, 31))}.must_raise(RuntimeError)
      _(error.message).must_include('01/10/2026 to 31/10/2026')
    end
  end

  describe "#search" do
    it "waits for the results to replace those there before the search, Export All or BOQ's message that there are none" do
      old_export_all_link = stand_in_link
      account = account_with_driver(stand_in_driver(elements: [old_export_all_link]))
      account.define_singleton_method(:click){|*| old_export_all_link.stale!}
      account.define_singleton_method(:wait_for){|*| true}
      account.send(:search)
      _(account.send(:stale?, old_export_all_link)).must_equal(true)
    end

    it "doesn't wait to see a link replaced where there was none" do
      account = account_with_driver(stand_in_driver(elements: []))
      account.define_singleton_method(:click){|*| true}
      account.define_singleton_method(:wait_for){|*| true}
      _(account.send(:search)).must_equal(true)
    end
  end

  describe "#transactions?" do
    it "is whether there's an Export All link, BOQ showing its message instead where there are none" do
      _(account_with_driver(stand_in_driver(elements: [stand_in_element])).send(:transactions?)).must_equal(true)
      _(account_with_driver(stand_in_driver(elements: [])).send(:transactions?)).must_equal(false)
    end
  end
end
