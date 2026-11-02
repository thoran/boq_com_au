# test/BoqComAu/Account_test.rb

# Notes:
# 1. No browser and no BOQ: only what doesn't depend on the site is tested. Every account which might reach for its browser is given a stand-in, so as none is started.

require_relative '../../lib/boq_com_au'

require 'minitest/autorun'
require 'minitest-spec-context'

describe BoqComAu::Account do
  def stand_in_driver
    driver = Object.new
    driver.define_singleton_method(:quit){@quit = true}
    driver.define_singleton_method(:quit?){!!@quit}
    driver
  end

  def account_with_driver(driver, logged_in: true)
    account = BoqComAu::Account.new
    account.instance_variable_set(:@driver, driver)
    account.instance_variable_set(:@logged_in, logged_in)
    account
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

  describe "#shutdown" do
    it "quits the browser even where logging out fails" do
      driver = stand_in_driver
      account = account_with_driver(driver)
      account.define_singleton_method(:logout){raise Selenium::WebDriver::Error::TimeoutError}
      _{account.shutdown}.must_raise(Selenium::WebDriver::Error::TimeoutError)
      _(driver.quit?).must_equal(true)
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

    it "is nil for browsers other than Chrome" do
      _(BoqComAu::Account.new(browser: :firefox).send(:default_driver_options)).must_be_nil
    end
  end
end
