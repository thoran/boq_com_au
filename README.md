# boq_com_au

## Description

Log into BOQ Classic Internet Banking (ib.boq.com.au), via Selenium WebDriver and WebAccount.

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

### Logging in, out, and shutting down
```ruby
  require 'boq_com_au'

  boq_account = BoqComAu::Account.new
  boq_account.login
  boq_account.driver # The logged-in browser.
  boq_account.logout
  boq_account.shutdown # Logs out if still logged in, then quits Chrome.
```

### Credentials

The username is the Customer Access Number. It and the password are given, or set afterwards:
```ruby
  boq_account = BoqComAu::Account.new(username: customer_access_number, password: password)
  boq_account.username, boq_account.password = customer_access_number, password
```
Where either is missing, `login` stops, saying which.

### The browser

Chrome is started with its automation flags masked. Given a `chrome_profile_directory`, it's started with that profile, kept between runs, so as the bank sees a returning browser rather than a fresh automated one; without one, each run has a new, temporary profile.
```ruby
  BoqComAu::Account.new(chrome_profile_directory: '~/path/to/chrome-profile')
```
Passing `browser:` or `driver_options:` to `BoqComAu::Account.new` replaces all of that, as for any WebAccount.

Where BOQ asks for a one-time code after logging on, `login` waits up to 30 seconds for it to be entered in the browser.

## Limitations

The login page's selectors were taken from the live page. BOQ's ids are generated, so things are found by their labels and text, and a change to the wording of the site will break it.

The tests cover only what doesn't depend on BOQ's site.

## Contributing

1. Fork it: https://github.com/thoran/boq_com_au/fork
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request
