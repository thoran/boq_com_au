# test/BoqComAu/Account_test.rb

# Notes:
# 1. No browser and no BOQ: only what doesn't depend on the site is tested.

require_relative '../../lib/boq_com_au'

require 'minitest/autorun'
require 'minitest-spec-context'

describe BoqComAu::Account do
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

    it "is nil for browsers other than Chrome" do
      _(BoqComAu::Account.new(browser: :firefox).send(:default_driver_options)).must_be_nil
    end
  end
end
