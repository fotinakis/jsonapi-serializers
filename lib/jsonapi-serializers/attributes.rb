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
      attr_accessor :to_one_associations
      attr_accessor :to_many_associations

      def attribute(name, options = {}, &block)
        # Don't allow users to declare "id" or "type" as attributes to comply with the spec,
        # but also because we need to keep these keys out of the serialized attributes hash.
        raise JSONAPI::DeclarationError.new(
          "'#{name}'' cannot be re-declared as a serializer attribute since it already required. " +
          "If you need to customize the #{name}, simply override the `#{name}` serializer method."
        ) if [:id, :type].include?(name.to_sym)

        add_attribute(name, options, &block)
      end

      def has_one(name, options = {})
        add_to_one_association(name, options)
      end

      def has_many(name, options = {})
        add_to_many_association(name, options)
      end

      def add_attribute(name, options = {}, &block)
        # Blocks are optional and can override the default attribute discovery. They are just
        # stored here, but evaluated by the Serializer within the instance context.
        @attributes_map ||= {}
        @attributes_map[name] = block_given? ? block : name
      end
      private :add_attribute

      def add_to_one_association(name, options = {}, &block)
        # Blocks are optional and can override the default attribute discovery. They are just
        # stored here, but evaluated by the Serializer within the instance context.
        @to_one_associations ||= {}
        @to_one_associations[name] = block_given? ? block : name
      end
      private :add_to_one_association

      def add_to_many_association(name, options = {}, &block)
        # Blocks are optional and can override the default attribute discovery. They are just
        # stored here, but evaluated by the Serializer within the instance context.
        @to_many_associations ||= {}
        @to_many_associations[name] = block_given? ? block : name
      end
      private :add_to_many_association
    end
  end
end
