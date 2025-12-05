# frozen_string_literal: true

require_relative 'lib/nbrb_currency/version'

Gem::Specification.new do |s|
  s.name         = 'nbrb_currency'
  s.version      = NbrbCurrencyVersion::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ['Alexander Grebennik']
  s.email        = ['sl.bug.sl@gmail.com']
  s.homepage     = 'https://github.com/slbug/nbrb_currency'
  s.summary      = 'Calculates exchange rates based on rates from National Bank of the Republic of Belarus. Money gem compatible.'
  s.description  = 'This gem reads exchange rates from the National Bank of the Republic of Belarus website. It uses it to calculates exchange rates. It is compatible with the money gem'
  s.license      = 'MIT'

  s.metadata['changelog_uri'] = 'https://github.com/slbug/nbrb_currency/blob/master/CHANGELOG.md'
  s.metadata['source_code_uri'] = 'https://github.com/slbug/nbrb_currency'
  s.metadata['bug_tracker_uri'] = 'https://github.com/slbug/nbrb_currency/issues'
  s.metadata['rubygems_mfa_required'] = 'true'

  s.required_ruby_version = '>= 3.4.7'

  s.add_dependency 'bigdecimal'
  s.add_dependency 'money', '>= 6.19'

  s.files = Dir.glob('lib/**/*') + %w(CHANGELOG.md LICENSE README.md)
  s.require_path = 'lib'
end
