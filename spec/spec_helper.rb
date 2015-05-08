require './lib/jsonapi-serializers'
require './spec/fixtures/serializers'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
