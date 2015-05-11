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

        # Internal serializer options, not exposed through attr_accessor. No touchie.
        @_include_linkages = options[:include_linkages] || []
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
          next if !should_include_attr?(attr_data[:options][:if], attr_data[:options][:unless])
          value = evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block])
          attributes[format_name(attribute_name)] = value
        end
        attributes
      end

      def should_include_attr?(if_method_name, unless_method_name)
        # Allow "if: :show_title?" and "unless: :hide_title?" attribute options.
        show_attr = true
        show_attr &&= send(if_method_name) if if_method_name
        show_attr &&= !send(unless_method_name) if unless_method_name
        show_attr
      end
      protected :should_include_attr?

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
          next if !should_include_attr?(attr_data[:options][:if], attr_data[:options][:unless])

          formatted_attribute_name = format_name(attribute_name)
          data[formatted_attribute_name] = {
            'self' => relationship_self_link(attribute_name),
            'related' => relationship_related_link(attribute_name),
          }
          if @_include_linkages.include?(formatted_attribute_name)
            related_object = evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block])
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
      end
      protected :build_to_one_data

      def build_to_many_data(data)
        return if self.class.to_many_associations.nil?
        self.class.to_many_associations.each do |attribute_name, attr_data|
          next if !should_include_attr?(attr_data[:options][:if], attr_data[:options][:unless])

          formatted_attribute_name = format_name(attribute_name)
          data[formatted_attribute_name] = {
            'self' => relationship_self_link(attribute_name),
            'related' => relationship_related_link(attribute_name),
          }

          # Spec: Resource linkage MUST be represented as one of the following:
          # - an empty array ([]) for empty to-many relationships.
          # - an array of linkage objects for non-empty to-many relationships.
          # http://jsonapi.org/format/#document-structure-resource-relationships
          if @_include_linkages.include?(formatted_attribute_name)
            data[formatted_attribute_name].merge!({'linkage' => []})
            related_objects = evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block]) || []
            related_objects.each do |related_object|
              related_object_serializer = JSONAPI::Serializer.find_serializer(related_object)
              data[formatted_attribute_name]['linkage'] << {
                'type' => related_object_serializer.type.to_s,
                'id' => related_object_serializer.id.to_s,
              }
            end
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
      # Normalize option strings to symbols.
      options[:is_collection] = options.delete('is_collection') || options[:is_collection] || false
      options[:include] = options.delete('include') || options[:include]
      options[:serializer] = options.delete('serializer') || options[:serializer]
      options[:context] = options.delete('context') || options[:context] || {}

      # Normalize includes.
      includes = options[:include]
      includes = (includes.is_a?(String) ? includes.split(',') : includes).uniq if includes

      # An internal-only structure that is passed through serializers as they are created.
      passthrough_options = {
        context: options[:context],
        serializer: options[:serializer],
        include: includes
      }

      if options[:is_collection] && !objects.respond_to?(:each)
        raise JSONAPI::Serializers::AmbiguousCollectionError.new(
          'Attempted to serialize a single object as a collection.')
      end

      # Automatically include linkage data for any relation that is also included.
      if includes
        direct_children_includes = includes.reject { |key| key.include?('.') }
        passthrough_options[:include_linkages] = direct_children_includes
      end

      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources.
      # - an array of resource objects or an empty array ([]), for resource collections.
      # http://jsonapi.org/format/#document-structure-top-level
      if options[:is_collection] && !objects.any?
        primary_data = []
      elsif !options[:is_collection] && objects.nil?
        primary_data = nil
      elsif options[:is_collection]
        # Have object collection.
        passthrough_options[:serializer] ||= find_serializer_class(objects.first)
        primary_data = serialize_primary_multi(objects, passthrough_options)
      else
        # Duck-typing check for a collection being passed without is_collection true.
        # We always must be told if serializing a collection because the JSON:API spec distinguishes
        # how to serialize null single resources vs. empty collections.
        if objects.respond_to?(:each)
          raise JSONAPI::Serializers::AmbiguousCollectionError.new(
            'Must provide `is_collection: true` to `serialize` when serializing collections.')
        end
        # Have single object.
        passthrough_options[:serializer] ||= find_serializer_class(objects)
        primary_data = serialize_primary(objects, passthrough_options)
      end
      result = {
        'data' => primary_data,
      }

      # If 'include' relationships are given, recursively find and include each object once.
      if includes
        # Given all the primary objects (either the single root object or collection of objects),
        # recursively search and find objects that match the given include paths.
        parsed_relationship_map = parse_relationship_paths(includes)
        objects = options[:is_collection] ? objects.to_a : [objects]
        included_objects = Set.new
        objects.compact.each do |obj|
          included_objects.merge(find_recursive_relationships(obj, parsed_relationship_map))
        end
        result['included'] = included_objects.to_a.map do |obj|
          # Determine the serializer class dynamically because each object might be different.
          passthrough_options[:serializer] = find_serializer_class(obj)
          serialize_primary(obj, passthrough_options)
        end
      end
      result
    end

    # ---

    def self.serialize_primary(object, options = {})
      serializer_class = options.fetch(:serializer)

      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources.
      # http://jsonapi.org/format/#document-structure-top-level
      return if object.nil?

      serializer = serializer_class.new(object, options)
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

    def self.serialize_primary_multi(objects, options = {})
      # Spec: Primary data MUST be either:
      # - an array of resource objects or an empty array ([]), for resource collections.
      # http://jsonapi.org/format/#document-structure-top-level
      return [] if !objects.any?

      objects.map { |obj| serialize_primary(obj, options) }
    end
    class << self; protected :serialize_primary_multi; end

    # Recursively find object relationships and add them to the result set.
    def self.find_recursive_relationships(root_object, parsed_relationship_map)
      result_set = Set.new
      parsed_relationship_map.each do |attribute_name, children|
        # Skip the sentinal value, but we need to preserve it for siblings.
        next if attribute_name == :_include

        serializer = JSONAPI::Serializer.find_serializer(root_object)
        unformatted_attr_name = serializer.unformat_name(attribute_name)

        # We know the name of this relationship, but we don't know where it is stored internally.
        # First, check if the attribute is a to-one association.
        object = nil
        is_valid_attr = false
        attr_data = (
          serializer.class.to_one_associations &&
          serializer.class.to_one_associations[unformatted_attr_name.to_sym])
        if attr_data
          # Found the attribute in the to-one associations.
          is_valid_attr = true
          is_to_many = false

          # Skip attribute if excluded by 'if' or 'unless'.
          next if !serializer.send(
            :should_include_attr?, attr_data[:options][:if], attr_data[:options][:unless])

          attr_or_block = attr_data[:attr_or_block]
          # Note: intentional high-coupling to instance method.
          object = serializer.send(:evaluate_attr_or_block, attribute_name, attr_or_block)
        else
          # If not, check if the attribute is a to-many association.
          attr_data = (
            serializer.class.to_many_associations &&
            serializer.class.to_many_associations[unformatted_attr_name.to_sym])
          if attr_data
            # Found the attribute in the to-many associations.
            is_valid_attr = true
            is_to_many = true
            # Skip attribute if excluded by 'if' or 'unless'.
            next if !serializer.send(
              :should_include_attr?, attr_data[:options][:if], attr_data[:options][:unless])

            attr_or_block = attr_data[:attr_or_block]
            # Note: intentional high-coupling to instance method.
            object = serializer.send(:evaluate_attr_or_block, attribute_name, attr_or_block)
          end
        end
        if !is_valid_attr
          raise JSONAPI::Serializers::InvalidIncludeError.new(
            "'#{attribute_name}' is not a valid include.")
        end
        next if object.nil?

        # We only include parent values if the sential value _include is set. This satifies the
        # spec note: A request for comments.author should not automatically also include comments
        # in the response. This can happen if the client already has the comments locally, and now
        # wants to fetch the associated authors without fetching the comments again.
        # http://jsonapi.org/format/#fetching-includes
        objects = is_to_many ? object : [object]
        if children[:_include] == true
          # Include the current level objects if the attribute exists.
          objects.each do |obj|
            result_set << obj
          end
        end

        # Recurse deeper!
        if !children.empty?
          # For each object we just loaded, find all deeper recursive relationships.
          objects.each do |obj|
            result_set.merge(find_recursive_relationships(obj, children))
          end
        end
      end
      result_set
    end
    class << self; protected :find_recursive_relationships; end

    # Takes a list of relationship paths and returns a hash as deep as the given paths.
    # The _include: true is a sentinal value that specifies whether the parent level should
    # be included.
    #
    # Example:
    #   Given: ['author', 'comments', 'comments.user']
    #   Returns: {
    #     'author' => {_include: true},
    #     'comments' => {_include: true, 'user' => {_include: true}},
    #   }
    def self.parse_relationship_paths(paths)
      relationships = {}
      paths.each { |path| merge_relationship_path(path, relationships) }
      relationships
    end
    class << self; protected :parse_relationship_paths; end

    def self.merge_relationship_path(path, data)
      parts = path.split('.', 2)
      current_level = parts[0].strip
      data[current_level] ||= {}

      if parts.length == 1
        # Leaf node.
        data[current_level].merge!({_include: true})
      elsif parts.length == 2
        # Need to recurse more.
        merge_relationship_path(parts[1], data[current_level])
      end
    end
    class << self; protected :merge_relationship_path; end
  end
end