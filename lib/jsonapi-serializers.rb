require "jsonapi-serializers/version"
require "jsonapi-serializers/attributes"
require "jsonapi-serializers/serializer"

module JSONAPI
  module Serializers
    class Error < Exception; end
    class DeclarationError < Error; end
  end
end
