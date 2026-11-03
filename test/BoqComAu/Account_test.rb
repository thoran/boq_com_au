# test/BoqComAu/Account_test.rb

# Notes:
# 1. No browser and no BOQ: only what doesn't depend on the site is tested. Every account which might reach for its browser is given a stand-in, so as none is started.

require_relative '../../lib/boq_com_au'

require 'minitest/autorun'
require 'minitest-spec-context'
require 'tmpdir'

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

  # Finds the elements by id given, though only after the number of looks given in drawn_after, as for a list Chosen hasn't drawn yet.
  def stand_in_driver(elements_by_id: {}, drawn_after: 0)
    driver = Object.new
    looks = 0
    driver.define_singleton_method(:attempt){|&block| block.call(self)}
    driver.define_singleton_method(:find_elements){|*, **by| (looks += 1) > drawn_after ? [elements_by_id[by[:id]]].compact : []}
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

  def touch(filename, mtime)
    File.write(filename, '')
    File.utime(mtime, mtime, filename)
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

    it "say which is missing where they're not given, rather than reading the environment" do
      ENV['BOQ_USERNAME'], ENV['BOQ_PASSWORD'] = 'customer', 'secret'
      account = BoqComAu::Account.new
      _(_{account.username}.must_raise(RuntimeError).message).must_include('No username')
      _(_{account.password}.must_raise(RuntimeError).message).must_include('No password')
    ensure
      ENV.delete('BOQ_USERNAME')
      ENV.delete('BOQ_PASSWORD')
    end
  end

  describe "#default_driver_options" do
    it "masks Chrome's automation flags, leaving the profile to Chrome where none is given" do
      options = BoqComAu::Account.new.send(:default_driver_options)
      _(options.args).must_include('--disable-blink-features=AutomationControlled')
      _(options.exclude_switches).must_include('enable-automation')
      _(options.args.grep(/--user-data-dir/)).must_be_empty
    end

    it "starts Chrome with the profile given, expanded" do
      options = BoqComAu::Account.new(chrome_profile_directory: '~/profiles/boq').send(:default_driver_options)
      _(options.args).must_include("--user-data-dir=#{File.expand_path('~/profiles/boq')}")
    end

    it "downloads into the download directory without asking, opening nothing" do
      options = BoqComAu::Account.new(download_directory: '~/statements').send(:default_driver_options)
      download = options.prefs[:download]
      _(download[:default_directory]).must_equal(File.expand_path('~/statements'))
      _(download[:prompt_for_download]).must_equal(false)
      _(download[:extensions_to_open]).must_equal('')
    end

    it "downloads into ~/Downloads where no directory is given" do
      _(BoqComAu::Account.new.download_directory).must_equal(File.expand_path('~/Downloads'))
    end

    it "is nil for browsers other than Chrome" do
      _(BoqComAu::Account.new(browser: :firefox).send(:default_driver_options)).must_be_nil
    end
  end

  describe "#click" do
    it "finds the element afresh where the one found first has been redrawn" do
      old_link, new_link = stand_in_link, stand_in_link
      old_link.stale!
      driver = stand_in_driver
      attempts = 0
      driver.define_singleton_method(:attempt) do |&block|
        block.call(self)
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        attempts += 1
        retry if attempts < 3
        raise
      end
      account = account_with_driver(driver)
      links = [old_link, new_link]
      account.define_singleton_method(:find){|*| links.shift}
      account.send(:click, {xpath: '//a'})
      _(new_link.clicked?).must_equal(true)
    end
  end

  describe "#newest_csv_filename" do
    it "is the newest CSV file in the download directory since the time given" do
      Dir.mktmpdir do |directory|
        since = Time.now - 60
        touch(File.join(directory, 'old.csv'), since - 60)
        touch(File.join(directory, 'new.csv'), since + 10)
        touch(File.join(directory, 'newer.csv'), since + 20)
        touch(File.join(directory, 'newest.csv.crdownload'), since + 30)
        account = BoqComAu::Account.new(download_directory: directory)
        _(account.send(:newest_csv_filename, since: since)).must_equal(File.join(directory, 'newer.csv'))
      end
    end

    it "is nil where none has appeared since" do
      Dir.mktmpdir do |directory|
        since = Time.now
        touch(File.join(directory, 'old.csv'), since - 60)
        _(BoqComAu::Account.new(download_directory: directory).send(:newest_csv_filename, since: since)).must_be_nil
      end
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
end
