require 'active_support/inflector'

module JSONAPI
  module Serializer
    def self.included(target)
      target.send(:include, InstanceMethods)
      target.extend ClassMethods
      target.class_eval do
        include JSONAPI::Attributes
      end
    end

    module InstanceMethods
      attr_accessor :object

      def initialize(object)
        @object = object
      end

      def id
        object.id
      end

      def type
        self.class.name.demodulize.sub('Serializer', '').downcase.pluralize
      end

      def attributes
        attributes = {}
        self.class.attributes_map.each do |attr_name, attr_name_or_block|
          if attr_name_or_block.is_a?(Proc)
            # A block was given, call it to get the value.
            value = instance_eval(&attr_name_or_block)
          else
            # Default behavior, call a method by the name of the attribute.
            value = object.send(attr_name_or_block)
          end
          attributes[format_attribute_name(attr_name)] = value
        end
        attributes
      end

      # By JSON:API spec convention, attribute names are dasherized. Override this to customize.
      def format_attribute_name(name)
        name.to_s.dasherize
      end

      def links
        {
          'self' => self_link,
        }
      end

      def self_link
        "#{route_namespace}/#{type}/#{id}"
      end

      def meta
      end

      # Override this to provide a namespace like "/api/v1" for all generated links.
      def route_namespace
      end
    end

    module ClassMethods
      def serialize_primary_data(object)
        serializer = self.new(object)
        data = {
          'id' => serializer.id,
          'type' => serializer.type,
          'attributes' => serializer.attributes,
        }

        # Merge in optional top-level members if they are non-nil.
        # http://jsonapi.org/format/#document-structure-resource-objects
        data.merge!({'attributes' => serializer.attributes}) if !serializer.attributes.nil?
        data.merge!({'links' => serializer.links}) if !serializer.links.nil?
        data.merge!({'meta' => serializer.meta}) if !serializer.meta.nil?
        data
      end
    end
  end
end