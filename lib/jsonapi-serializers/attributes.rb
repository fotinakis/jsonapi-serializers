module JSONAPI
  module Attributes
    def self.included(target)
      target.send(:include, InstanceMethods)
      target.extend ClassMethods

      target.class_eval do
        def self.inherited(target)
          [:attributes_map, :to_one_associations, :to_many_associations]
            .each{|k|
              key = "@#{k}"
              attr = self.instance_variable_get(key)
              target.instance_variable_set(key, attr.dup) if attr
            }
        end
      end
    end

    module InstanceMethods
    end

    module ClassMethods
      attr_accessor :attributes_map
      attr_accessor :to_one_associations
      attr_accessor :to_many_associations

      def attribute(name, options = {}, &block)
        add_attribute(name, options, &block)
      end

      def attributes(*names)
        names.each { |name| add_attribute(name) }
      end

      def has_one(name, options = {}, &block)
        add_to_one_association(name, options, &block)
      end

      def has_many(name, options = {}, &block)
        add_to_many_association(name, options, &block)
      end

      def add_attribute(name, options = {}, &block)
        # Blocks are optional and can override the default attribute discovery. They are just
        # stored here, but evaluated by the Serializer within the instance context.
        @attributes_map ||= {}
        @attributes_map[name] = {
          attr_or_block: block_given? ? block : name,
          options: options,
        }
      end
      private :add_attribute

      def add_to_one_association(name, options = {}, &block)
        options[:include_links] = options.fetch(:include_links, true)
        options[:include_data] = options.fetch(:include_data, false)
        @to_one_associations ||= {}
        @to_one_associations[name] = {
          attr_or_block: block_given? ? block : name,
          options: options,
        }
      end
      private :add_to_one_association

      def add_to_many_association(name, options = {}, &block)
        options[:include_links] = options.fetch(:include_links, true)
        options[:include_data] = options.fetch(:include_data, false)
        @to_many_associations ||= {}
        @to_many_associations[name] = {
          attr_or_block: block_given? ? block : name,
          options: options,
        }
      end
      private :add_to_many_association
    end
  end
end
