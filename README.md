# boq_com_au

## Description

Log into BOQ Classic Internet Banking (ib.boq.com.au) and export an account's transactions as a CSV file, via Selenium WebDriver and WebAccount.

myBOQ, BOQ's newer internet banking site, isn't covered.

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'boq_com_au'
```
And then execute:
```shell
$ bundle
```
Or install it yourself as:
```shell
$ gem install boq_com_au
```

## Usage

### Downloading transactions
```ruby
  require 'boq_com_au'

  boq_account = BoqComAu::Account.new
  boq_account.login
  boq_account.download_transactions(account_number: '12345678')
  # => "/Users/me/Downloads/12345678_20261103.csv"
  boq_account.shutdown # Logs out if still logged in, then quits the browser.
```
The account is picked from the list by the digits of its number alone, so `'12345678'` and `'1234 5678'` are the same. Its transactions are exported with Export All as Comma Delimited Format (CSV).

Without dates, the transactions are those BOQ shows on choosing the account. Given a period or dates, they're set under Advanced Search and searched on first:
```ruby
  boq_account.download_transactions(account_number: '12345678', period: :last_month)
  boq_account.download_transactions(account_number: '12345678', period: :all) # The last year.
  boq_account.download_transactions(account_number: '12345678', from_date: '2026-01-01', to_date: '2026-06-30')
```
Dates are Dates, or Strings `Date.parse` can read. Where only one of `from_date` and `to_date` is given, the other is a year ago or today.

`download_transactions` waits for the download to finish, and returns the newest CSV file to have appeared in the download directory since Download was clicked. BOQ names it after the account number and the day's date, and the browser adds a number to that where a file of the name is there already.

Or in one step, logging in, downloading, and shutting down even where the download fails:
```ruby
  BoqComAu::Transactions.download_csv_file(account_number: '12345678', period: :last_month)
```
It takes `period:`, `from_date:` and `to_date:` as `download_transactions` does. Any other keyword arguments are passed to `BoqComAu::Account.new`.

### Credentials

The username is the Customer Access Number. It and the password are given, or set afterwards:
```ruby
  boq_account = BoqComAu::Account.new(username: customer_access_number, password: password)
  boq_account.username, boq_account.password = customer_access_number, password
```
Where either is missing, `login` stops, saying which.

### The browser

The browser is WebAccount's: Chrome, unless `browser: :firefox` is given, Chrome being started with its automation flags masked. Given a `profile_directory`, it's started with that profile, kept between runs, so as the bank sees a returning browser rather than a fresh automated one; without one, each run has a new, temporary profile.
```ruby
  BoqComAu::Account.new(profile_directory: '~/path/to/profile')
  BoqComAu::Account.new(browser: :firefox, profile_directory: '~/path/to/firefox-profile')
```
It downloads into `download_directory`, `~/Downloads` unless given, without asking where, and opens nothing it downloads:
```ruby
  BoqComAu::Account.new(download_directory: '~/path/to/statements')
```
`headless:`, `window_size:` and `user_agent:` are passed to WebAccount too. Passing `driver_options:` replaces the browser's options altogether.

Where BOQ asks for a one-time code after logging on, `login` waits up to 30 seconds for it to be entered in the browser.

## Limitations

The selectors were taken from the live site. BOQ's ids are generated, so things are found by their labels and text, and a change to the wording of the site will break it.

The tests cover only what doesn't depend on BOQ's site.

## Contributing

1. Fork it: https://github.com/thoran/boq_com_au/fork
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request
