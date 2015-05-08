module JSONAPI
  module Serializer
    def self.included(target)
      target.send(:include, InstanceMethods)
      target.extend ClassMethods
    end

    module InstanceMethods
    end

    module ClassMethods
      def attribute(key)
      end
    end
  end
end