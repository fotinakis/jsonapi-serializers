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
      attr_accessor :model

      def initialize(model)
        @model = model
      end

      def id
        model.id
      end

      def type
        self.class.name.demodulize.sub('Serializer', '').downcase.pluralize
      end

      def attributes
        attributes = {}
        self.class.serializable_attributes.each do |key, model_attr_name|
          attributes[key] = model.send(model_attr_name)
        end
        attributes
      end

      def links
        {
          'self' => self_link,
        }
      end

      def self_link
        format_route(type, id)
      end

      def format_route(type, id)
        "#{route_namespace}/#{type}/#{id}"
      end

      def meta
      end

      # Override this to provide a namespace like "/api/v1" for all generated links.
      def route_namespace
      end
    end

    module ClassMethods
      def serialize_primary_data(model)
        serializer = self.new(model)
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