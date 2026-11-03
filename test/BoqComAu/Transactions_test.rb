# test/BoqComAu/Transactions_test.rb

# Notes:
# 1. BoqComAu::Account.new is swapped for a stand-in for the length of each example and put back afterwards, so as no browser is started.

require_relative '../../lib/boq_com_au'

require 'minitest/autorun'
require 'minitest-spec-context'

describe BoqComAu::Transactions do
  def with_stand_in_account(download: ->{'/downloads/transactions.csv'})
    account = Object.new
    account.define_singleton_method(:download_transactions){|account_number:| (@asked ||= []) << account_number; download.call}
    account.define_singleton_method(:asked){@asked}
    account.define_singleton_method(:shutdown){@shut_down = true}
    account.define_singleton_method(:shut_down?){!!@shut_down}
    arguments = []
    original = BoqComAu::Account.method(:new)
    BoqComAu::Account.define_singleton_method(:new){|**args| arguments << args; account}
    yield account, arguments
  ensure
    BoqComAu::Account.define_singleton_method(:new, original)
  end

  describe ".download_csv_file" do
    it "is the file downloaded, for the account given, the other arguments going to the account, which is shut down" do
      with_stand_in_account do |account, arguments|
        _(BoqComAu::Transactions.download_csv_file(account_number: '12345678', download_directory: '/downloads')).must_equal('/downloads/transactions.csv')
        _(account.asked).must_equal(['12345678'])
        _(arguments).must_equal([{download_directory: '/downloads'}])
        _(account.shut_down?).must_equal(true)
      end
    end

    it "shuts the account down even where the download fails" do
      with_stand_in_account(download: ->{raise Selenium::WebDriver::Error::TimeoutError}) do |account, _arguments|
        _{BoqComAu::Transactions.download_csv_file(account_number: '12345678')}.must_raise(Selenium::WebDriver::Error::TimeoutError)
        _(account.shut_down?).must_equal(true)
      end
    end
  end
end
