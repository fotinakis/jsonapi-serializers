require 'set'
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

    module ClassMethods
      def serialize(object, options = {})
        # Since this is being called on the class directly and not the module, override the
        # serializer option to be the current class.
        options[:serializer] = self

        JSONAPI::Serializer.serialize(object, options)
      end
    end

    module InstanceMethods
      attr_accessor :object
      attr_accessor :context

      def initialize(object, options = {})
        @object = object
        @context = options[:context] || {}
      end

      # Override this method to customize how the ID is set.
      # Always return a string from this method to conform with the JSON:API spec.
      def id
        object.id.to_s
      end

      # Override this method to customize the type name.
      def type
        object.class.name.demodulize.tableize.dasherize
      end

      # By JSON:API spec convention, attribute names are dasherized. Override this to customize.
      def format_name(attribute_name)
        attribute_name.to_s.dasherize
      end

      def unformat_name(attribute_name)
        attribute_name.to_s.underscore
      end

      def self_link
        "/#{type}/#{id}"
      end

      def relationship_self_link(attribute_name)
        "#{self_link}/links/#{format_name(attribute_name)}"
      end

      def relationship_related_link(attribute_name)
        "#{self_link}/#{format_name(attribute_name)}"
      end

      # Override to provide resource-object-level meta data.
      def meta
      end

      def links
        data = {}
        data.merge!({'self' => self_link}) if self_link
        build_to_one_data(data)
        build_to_many_data(data)
        data
      end

      def attributes
        attributes = {}
        self.class.attributes_map.each do |attribute_name, attr_data|
          next if !should_include?(attr_data[:options][:if], attr_data[:options][:unless])
          value = evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block])
          attributes[format_name(attribute_name)] = value
        end
        attributes
      end

      def should_include?(if_method_name, unless_method_name)
        # Allow "if: :show_title?" and "unless: :hide_title?" attribute options.
        show_attr = true
        show_attr &&= send(if_method_name) if if_method_name
        show_attr &&= !send(unless_method_name) if unless_method_name
        show_attr
      end
      protected :should_include?

      def evaluate_attr_or_block(attribute_name, attr_or_block)
        if attr_or_block.is_a?(Proc)
          # A custom block was given, call it to get the value.
          instance_eval(&attr_or_block)
        else
          # Default behavior, call a method by the name of the attribute.
          object.send(attr_or_block)
        end
      end
      protected :evaluate_attr_or_block

      def build_to_one_data(data)
        return if self.class.to_one_associations.nil?
        self.class.to_one_associations.each do |attribute_name, attr_data|
          next if !should_include?(attr_data[:options][:if], attr_data[:options][:unless])
          related_object = evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block])

          formatted_attribute_name = format_name(attribute_name)
          data[formatted_attribute_name] = {
            'self' => relationship_self_link(attribute_name),
            'related' => relationship_related_link(attribute_name),
          }
          if related_object.nil?
            # Spec: Resource linkage MUST be represented as one of the following:
            # - null for empty to-one relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            data[formatted_attribute_name].merge!({'linkage' => nil})
          else
            related_object_serializer = JSONAPI::Serializer.find_serializer(related_object)
            data[formatted_attribute_name].merge!({
              'linkage' => {
                'type' => related_object_serializer.type.to_s,
                'id' => related_object_serializer.id.to_s,
              },
            })
          end
        end
      end
      protected :build_to_one_data

      def build_to_many_data(data)
        return if self.class.to_many_associations.nil?
        self.class.to_many_associations.each do |attribute_name, attr_data|
          next if !should_include?(attr_data[:options][:if], attr_data[:options][:unless])
          related_objects = evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block]) || []

          formatted_attribute_name = format_name(attribute_name)
          data[formatted_attribute_name] = {
            'self' => relationship_self_link(attribute_name),
            'related' => relationship_related_link(attribute_name),
          }

          # Spec: Resource linkage MUST be represented as one of the following:
          # - an empty array ([]) for empty to-many relationships.
          # - an array of linkage objects for non-empty to-many relationships.
          # http://jsonapi.org/format/#document-structure-resource-relationships
          data[formatted_attribute_name].merge!({'linkage' => []})
          related_objects.each do |related_object|
            related_object_serializer = JSONAPI::Serializer.find_serializer(related_object)
            data[formatted_attribute_name]['linkage'] << {
              'type' => related_object_serializer.type.to_s,
              'id' => related_object_serializer.id.to_s,
            }
          end
        end
      end
      protected :build_to_many_data
    end

    def self.find_serializer_class_name(object)
      "#{object.class.name}Serializer"
    end

    def self.find_serializer_class(object)
      class_name = find_serializer_class_name(object)
      class_name.constantize
    end

    def self.find_serializer(object)
      find_serializer_class(object).new(object)
    end

    def self.serialize(objects, options = {})
      # Normalize option symbols and strings.
      options[:is_collection] = options.delete('is_collection') || options[:is_collection] || false
      options[:include] = options.delete('include') || options[:include]
      options[:serializer] = options.delete('serializer') || options[:serializer]
      options[:context] = options.delete('context') || options[:context] || {}
      passthrough_options = {context: options[:context]}

      if options[:is_collection] && !objects.respond_to?(:each)
        raise JSONAPI::Serializers::AmbiguousCollectionError.new(
          'Attempted to serialize a single object as a collection.')
      end

      # Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources.
      # - an array of resource objects or an empty array ([]), for resource collections.
      # http://jsonapi.org/format/#document-structure-top-level
      if options[:is_collection] && !objects.any?
        primary_data = []
      elsif !options[:is_collection] && objects.nil?
        primary_data = nil
      elsif options[:is_collection]
        # Have object collection.
        serializer_class = options[:serializer] || find_serializer_class(objects.first)
        primary_data = serialize_primary_multi(objects, serializer_class, passthrough_options)
      else
        # Duck-typing check for a collection being passed without is_collection true.
        # We always must be told if serializing a collection because the JSON:API spec distinguishes
        # how to serialize null single resources vs. empty collections.
        if objects.respond_to?(:each)
          raise JSONAPI::Serializers::AmbiguousCollectionError.new(
            'Must provide `is_collection: true` to `serialize` when serializing collections.')
        end
        # Have single object.
        serializer_class = options[:serializer] || find_serializer_class(objects)
        primary_data = serialize_primary(objects, serializer_class, passthrough_options)
      end
      result = {
        'data' => primary_data,
      }

      # If 'include' relationships are given, recursively find and include each object once.
      if options[:include]
        # Parse the given relationship paths.
        parsed_relationship_map = parse_relationship_paths(options[:include])

        # Starting with every primary root object, recursively search and find objects that match
        # the given include paths.
        objects = options[:is_collection] ? objects : [objects]
        included_objects = Set.new
        objects.each do |obj|
          included_objects.merge(find_recursive_relationships(obj, parsed_relationship_map))
        end
        result['included'] = included_objects.to_a.map do |obj|
          serialize_primary(obj, find_serializer_class(obj))
        end
      end
      result
    end

    # ---

    def self.serialize_primary_multi(objects, serializer_class, options = {})
      # Primary data MUST be either:
      # - an array of resource objects or an empty array ([]), for resource collections.
      # http://jsonapi.org/format/#document-structure-top-level
      return [] if !objects.any?

      objects.map { |obj| serialize_primary(obj, serializer_class, options) }
    end
    class << self; protected :serialize_primary_multi; end

    def self.serialize_primary(object, serializer_class, options = {})
      # Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources.
      # http://jsonapi.org/format/#document-structure-top-level
      return if object.nil?

      serializer = serializer_class.new(object, context: options[:context])
      data = {
        'id' => serializer.id.to_s,
        'type' => serializer.type.to_s,
        'attributes' => serializer.attributes,
      }

      # Merge in optional top-level members if they are non-nil.
      # http://jsonapi.org/format/#document-structure-resource-objects
      data.merge!({'attributes' => serializer.attributes}) if !serializer.attributes.nil?
      data.merge!({'links' => serializer.links}) if !serializer.links.nil?
      data.merge!({'meta' => serializer.meta}) if !serializer.meta.nil?
      data
    end
    class << self; protected :serialize_primary; end

    # Recursively find object relationships and add them to the result set.
    def self.find_recursive_relationships(root_object, parsed_relationship_map, result_set = nil)
      result_set = Set.new
      parsed_relationship_map.each do |attribute_name, value|
        serializer = JSONAPI::Serializer.find_serializer(root_object)
        unformatted_attr_name = serializer.unformat_name(attribute_name)

        # TODO: need to fail with a custom error if the given include attribute doesn't exist.
        object = nil

        # First, check if the attribute is a to-one association.
        attr_data = serializer.class.to_one_associations[unformatted_attr_name.to_sym]
        if attr_data
          is_to_many = false

          # Skip attribute if excluded by 'if' or 'unless'.
          next if !serializer.send(
            :should_include?, attr_data[:options][:if], attr_data[:options][:unless])

          # Note: intentional high-coupling to instance method.
          attr_or_block = attr_data[:attr_or_block]
          object = serializer.send(:evaluate_attr_or_block, attribute_name, attr_or_block)
        else
          # If not, check if the attribute is a to-many association.
          is_to_many = true
          attr_data = serializer.class.to_many_associations[unformatted_attr_name.to_sym]
          if attr_data
            # Skip attribute if excluded by 'if' or 'unless'.
            next if !serializer.send(
              :should_include?, attr_data[:options][:if], attr_data[:options][:unless])

            # Note: intentional high-coupling to instance method.
            attr_or_block = attr_data[:attr_or_block]
            object = serializer.send(:evaluate_attr_or_block, attribute_name, attr_or_block)
          end
        end
        next if object.nil?

        if value['_include'] == true
          # Include the current level objects if the attribute exists.
          objects = is_to_many ? object : [object]
          objects.each do |obj|
            result_set << obj
          end
        end

        # Recurse deeper!
        # find_recursive_relationships()
      end
      result_set
    end
    class << self; protected :find_recursive_relationships; end

    # Takes a list of relationship paths and returns a hash as deep as the given paths.
    # The '_include' => true is a sentinal value that specifies whether the parent level should
    # be included.
    #
    # Example:
    #   Given: ['author', 'comments', 'comments.user']
    #   Returns: {
    #     'author' => {'_include' => true},
    #     'comments' => {'_include' => true, 'user' => {'_include' => true}},
    #   }
    def self.parse_relationship_paths(paths)
      paths = paths.split(',') if paths.is_a?(String)

      relationships = {}
      paths.each do |path|
        path = path.to_s.strip
        if !path.include?('.')
          # Base case.
          relationships[path] ||= {}
          relationships[path].merge!({'_include' => true})
        else
          # Recurisive case.
          first_level, rest = path.split('.', 2)
          relationships[first_level] ||= {}
          relationships[first_level].merge!(parse_relationship_paths([rest]))
        end
      end
      relationships
    end
    class << self; protected :parse_relationship_paths; end
  end
end