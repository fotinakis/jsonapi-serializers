require "jsonapi-serializers/version"
require "jsonapi-serializers/attributes"
require "jsonapi-serializers/serializer"

module JSONAPI
  class Error < Exception; end
  class DeclarationError < Error; end

  module Serializers
  end
end
