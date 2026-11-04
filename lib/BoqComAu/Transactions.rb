# BoqComAu/Transactions.rb
# BoqComAu::Transactions

require_relative './Account'

module BoqComAu
  module Transactions
    class << self
      # Returns the name of the CSV file downloaded.
      def download_csv_file(account_number:, period: nil, from_date: nil, to_date: nil, **account_args)
        boq_account = BoqComAu::Account.new(**account_args)
        boq_account.download_transactions(account_number: account_number, period: period, from_date: from_date, to_date: to_date)
      ensure
        boq_account&.shutdown
      end
    end # class << self
  end
end
