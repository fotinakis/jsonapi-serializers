module JSONAPI
  module Attributes
    def self.included(target)
      target.send(:include, InstanceMethods)
      target.extend ClassMethods
    end

    module InstanceMethods
    end

    module ClassMethods
      attr_accessor :attributes_map

      def attribute(name, options = {}, &block)
        # Don't allow users to declare "id" or "type" as attributes to comply with the spec,
        # but also because we need to keep these keys out of the serialized attributes hash.
        raise JSONAPI::DeclarationError.new(
          "'#{name}'' cannot be re-declared as a serializer attribute since it already required. " +
          "If you need to customize the #{name}, simply override the `#{name}` serializer method."
        ) if [:id, :type].include?(name.to_sym)

        add_attribute(name, options, &block)
      end

      def has_one(name)
        # add_to_links
      end

      def add_attribute(name, options = {}, &block)
        # @attributes_map will be a mapping of attribute names --> same attribute name or a block.
        # In the instance, a block indicates that it should be evaluated to determine the value.
        # An attribute name indicates that the object's method by the same name should be called.
        @attributes_map ||= {}
        @attributes_map[name] = block_given? ? block : name
      end
      private :add_attribute
    end
  end
end
