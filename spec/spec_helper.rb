require 'travis/settings'

module Travis
  def self.config
    @config ||= { encryption: { key: 'secret' * 10 } }
  end
end

RSpec.configure do |c|
  c.mock_with :mocha
  # c.backtrace_clean_patterns.clear
end

