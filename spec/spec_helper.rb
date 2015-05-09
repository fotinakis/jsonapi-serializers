require 'factory_girl'
require './lib/jsonapi-serializers'
require './spec/support/serializers'

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:each) do
    # Force FactoryGirl sequences to be fully reset before each test run to simplify ID testing
    # since we are not using a database or real fixtures. Inside of each test case, IDs will
    # increment per type starting at 1.
    FactoryGirl.reload
    load './spec/support/factory.rb'
  end
end
