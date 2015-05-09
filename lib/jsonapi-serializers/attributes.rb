module JSONAPI
  module Attributes
    def self.included(target)
      target.send(:include, InstanceMethods)
      target.extend ClassMethods
    end

    module InstanceMethods
    end

    module ClassMethods
      attr_accessor :serializable_attributes

      def attribute(name)
        # Don't allow users to declare "id" or "type" as attributes to comply with the spec,
        # but also because we need to keep these keys out of the serialized attributes hash.
        raise JSONAPI::DeclarationError.new(
          "'#{name}'' cannot be re-declared as a serializer attribute since it required. " +
          "If you need to customize it, simply override the `#{name}` method in the serializer."
        ) if [:id, :type].include?(name.to_sym)

        add_to_serializable(name)
      end

      def add_to_serializable(name, options = {})
        options[:key] ||= name.to_s.dasherize

        @serializable_attributes ||= {}
        @serializable_attributes[options[:key]] = name
      end
      private :add_to_serializable
    end
  end
end
