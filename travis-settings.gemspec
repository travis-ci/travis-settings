$:.unshift File.expand_path('lib', __dir__)

Gem::Specification.new do |s|
  s.name         = 'travis-settings'
  s.version      = '0.0.1'
  s.authors      = ['Travis CI']
  s.email        = 'contact@travis-ci.org'
  s.homepage     = 'https://github.com/travis-ci/travis-settings'
  s.summary      = 'Travis CI Settings'
  s.description  = "#{s.summary}."
  s.license      = 'MIT'

  s.files        = Dir['{lib/**/*,spec/**/*,[A-Z]*}']
  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rubyforge_project = '[none]'

  s.add_dependency 'activemodel'
  s.add_dependency 'virtus'
end
