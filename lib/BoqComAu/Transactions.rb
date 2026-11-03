# BoqComAu/Transactions.rb
# BoqComAu::Transactions

require_relative './Account'

module BoqComAu
  module Transactions
    class << self
      # Returns the name of the CSV file downloaded.
      def download_csv_file(account_number:, **account_args)
        boq_account = BoqComAu::Account.new(**account_args)
        boq_account.download_transactions(account_number: account_number)
      ensure
        boq_account&.shutdown
      end
    end # class << self
  end
end
