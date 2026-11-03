require_relative './lib/BoqComAu/VERSION'

class Gem::Specification
  def dependencies=(gems)
    gems.each{|gem| add_dependency(*gem)}
  end

  def development_dependencies=(gems)
    gems.each{|gem| add_development_dependency(*gem)}
  end
end

Gem::Specification.new do |spec|
  spec.name = 'boq_com_au'
  spec.version = BoqComAu::VERSION

  spec.summary = "Download transactions from BOQ Classic Internet Banking via Selenium WebDriver."
  spec.description = "Log into BOQ Classic Internet Banking with a Customer Access Number and password, and export an account's transactions as a CSV file."

  spec.author = 'thoran'
  spec.email = 'code@thoran.com'
  spec.homepage = 'https://github.com/thoran/boq_com_au'
  spec.license = 'MIT'

  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.3'

  spec.files = [
    'boq_com_au.gemspec',
    Dir['lib/**/*.rb'],
    Dir['test/**/*.rb'],
    'CHANGELOG',
    'Gemfile',
    'LICENSE',
    'Rakefile',
    'README.md',
  ].flatten

  spec.dependencies = [
    ['selenium-webdriver', '>= 4.0'],
    ['webaccount', '>= 0.6.1']
  ]

  spec.development_dependencies = %w{
    minitest
    minitest-spec-context
    rake
  }
end
