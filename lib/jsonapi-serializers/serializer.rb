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
      @@class_names = {}
      @@formatted_attribute_names = {}
      @@unformatted_attribute_names = {}

      attr_accessor :object
      attr_accessor :context
      attr_accessor :base_url

      def initialize(object, options = {})
        @object = object
        @options = options
        @context = options[:context] || {}
        @base_url = options[:base_url]

        # Internal serializer options, not exposed through attr_accessor. No touchie.
        @_fields = options[:fields] || {}
        @_include_linkages = options[:include_linkages] || []
      end

      # Override this to customize the JSON:API "id" for this object.
      # Always return a string from this method to conform with the JSON:API spec.
      def id
        object.id.to_s
      end

      # Override this to customize the JSON:API "type" for this object.
      # By default, the type is the object's class name lowercased, pluralized, and dasherized,
      # per the spec naming recommendations: http://jsonapi.org/recommendations/#naming
      # For example, 'MyApp::LongCommment' will become the 'long-comments' type.
      def type
        class_name = object.class.name
        @@class_names[class_name] ||= class_name.demodulize.tableize.dasherize.freeze
      end

      # Override this to customize how attribute names are formatted.
      # By default, attribute names are dasherized per the spec naming recommendations:
      # http://jsonapi.org/recommendations/#naming
      def format_name(attribute_name)
        attr_name = attribute_name.to_s
        @@formatted_attribute_names[attr_name] ||= attr_name.dasherize.freeze
      end

      # The opposite of format_name. Override this if you override format_name.
      def unformat_name(attribute_name)
        attr_name = attribute_name.to_s
        @@unformatted_attribute_names[attr_name] ||= attr_name.underscore.freeze
      end

      # Override this to provide resource-object jsonapi object containing the version in use.
      # http://jsonapi.org/format/#document-jsonapi-object
      def jsonapi
      end

      # Override this to provide resource-object metadata.
      # http://jsonapi.org/format/#document-structure-resource-objects
      def meta
      end

      # Override this to set a base URL (http://example.com) for all links. No trailing slash.
      def base_url
        @base_url
      end

      def self_link
        "#{base_url}/#{type}/#{id}"
      end

      def relationship_self_link(attribute_name)
        "#{self_link}/relationships/#{format_name(attribute_name)}"
      end

      def relationship_related_link(attribute_name)
        "#{self_link}/#{format_name(attribute_name)}"
      end

      def links
        data = {}
        data['self'] = self_link if self_link
        data
      end

      def relationships
        data = {}
        # Merge in data for has_one relationships.
        has_one_relationships.each do |attribute_name, attr_data|
          formatted_attribute_name = format_name(attribute_name)

          data[formatted_attribute_name] = {}

          if attr_data[:options][:include_links]
            links_self = relationship_self_link(attribute_name)
            links_related = relationship_related_link(attribute_name)
            data[formatted_attribute_name]['links'] = {} if links_self || links_related
            data[formatted_attribute_name]['links']['self'] = links_self if links_self
            data[formatted_attribute_name]['links']['related'] = links_related if links_related
          end

          if @_include_linkages.include?(formatted_attribute_name) || attr_data[:options][:include_data]
            object = has_one_relationship(attribute_name, attr_data)
            if object.nil?
              # Spec: Resource linkage MUST be represented as one of the following:
              # - null for empty to-one relationships.
              # http://jsonapi.org/format/#document-structure-resource-relationships
              data[formatted_attribute_name]['data'] = nil
            else
              related_object_serializer = JSONAPI::Serializer.find_serializer(object, @options)
              data[formatted_attribute_name]['data'] = {
                'type' => related_object_serializer.type.to_s,
                'id' => related_object_serializer.id.to_s,
              }
            end
          end
        end

        # Merge in data for has_many relationships.
        has_many_relationships.each do |attribute_name, attr_data|
          formatted_attribute_name = format_name(attribute_name)

          data[formatted_attribute_name] = {}

          if attr_data[:options][:include_links]
            links_self = relationship_self_link(attribute_name)
            links_related = relationship_related_link(attribute_name)
            data[formatted_attribute_name]['links'] = {} if links_self || links_related
            data[formatted_attribute_name]['links']['self'] = links_self if links_self
            data[formatted_attribute_name]['links']['related'] = links_related if links_related
          end

          # Spec: Resource linkage MUST be represented as one of the following:
          # - an empty array ([]) for empty to-many relationships.
          # - an array of linkage objects for non-empty to-many relationships.
          # http://jsonapi.org/format/#document-structure-resource-relationships
          if @_include_linkages.include?(formatted_attribute_name) || attr_data[:options][:include_data]
            data[formatted_attribute_name]['data'] = []
            objects = has_many_relationship(attribute_name, attr_data) || []
            objects.each do |obj|
              related_object_serializer = JSONAPI::Serializer.find_serializer(obj, @options)
              data[formatted_attribute_name]['data'] << {
                'type' => related_object_serializer.type.to_s,
                'id' => related_object_serializer.id.to_s,
              }
            end
          end
        end
        data
      end

      def attributes
        return {} if self.class.attributes_map.nil?
        attributes = {}
        self.class.attributes_map.each do |attribute_name, attr_data|
          next if !should_include_attr?(attribute_name, attr_data)
          value = evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block])
          attributes[format_name(attribute_name)] = value
        end
        attributes
      end

      def has_one_relationships
        return {} if self.class.to_one_associations.nil?
        data = {}
        self.class.to_one_associations.each do |attribute_name, attr_data|
          next if !should_include_attr?(attribute_name, attr_data)
          data[attribute_name] = attr_data
        end
        data
      end

      def has_one_relationship(attribute_name, attr_data)
        evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block])
      end

      def has_many_relationships
        return {} if self.class.to_many_associations.nil?
        data = {}
        self.class.to_many_associations.each do |attribute_name, attr_data|
          next if !should_include_attr?(attribute_name, attr_data)
          data[attribute_name] = attr_data
        end
        data
      end

      def has_many_relationship(attribute_name, attr_data)
        evaluate_attr_or_block(attribute_name, attr_data[:attr_or_block])
      end

      def should_include_attr?(attribute_name, attr_data)
        # Allow "if: :show_title?" and "unless: :hide_title?" attribute options.
        if_method_name = attr_data[:options][:if]
        unless_method_name = attr_data[:options][:unless]
        formatted_attribute_name = format_name(attribute_name).to_sym
        show_attr = true
        show_attr &&= send(if_method_name) if if_method_name
        show_attr &&= !send(unless_method_name) if unless_method_name
        show_attr &&= @_fields[type.to_s].include?(formatted_attribute_name) if @_fields[type.to_s]
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
    end

    def self.find_serializer_class_name(object, options)
      if options[:namespace]
        return "#{options[:namespace]}::#{object.class.name}Serializer"
      end
      if object.respond_to?(:jsonapi_serializer_class_name)
        return object.jsonapi_serializer_class_name.to_s
      end
      "#{object.class.name}Serializer"
    end

    def self.find_serializer_class(object, options)
      class_name = find_serializer_class_name(object, options)
      class_name.constantize
    end

    def self.find_serializer(object, options)
      find_serializer_class(object, options).new(object, options)
    end

    def self.serialize(objects, options = {})
      # Normalize option strings to symbols.
      options[:is_collection] = options.delete('is_collection') || options[:is_collection] || false
      options[:include] = options.delete('include') || options[:include]
      options[:serializer] = options.delete('serializer') || options[:serializer]
      options[:namespace] = options.delete('namespace') || options[:namespace]
      options[:context] = options.delete('context') || options[:context] || {}
      options[:skip_collection_check] = options.delete('skip_collection_check') || options[:skip_collection_check] || false
      options[:base_url] = options.delete('base_url') || options[:base_url]
      options[:jsonapi] = options.delete('jsonapi') || options[:jsonapi]
      options[:meta] = options.delete('meta') || options[:meta]
      options[:links] = options.delete('links') || options[:links]
      options[:fields] = options.delete('fields') || options[:fields] || {}

      # Deprecated: use serialize_errors method instead
      options[:errors] = options.delete('errors') || options[:errors]

      # Normalize includes.
      includes = options[:include]
      includes = (includes.is_a?(String) ? includes.split(',') : includes).uniq if includes

      # Transforms input so that the comma-separated fields are separate symbols in array
      # and keys are stringified
      # Example:
      # {posts: 'title,author,long_comments'} => {'posts' => [:title, :author, :long_comments]}
      # {posts: ['title', 'author', 'long_comments'} => {'posts' => [:title, :author, :long_comments]}
      #
      fields = {}
      # Normalize fields to accept a comma-separated string or an array of strings.
      options[:fields].map do |type, whitelisted_fields|
        whitelisted_fields = [whitelisted_fields] if whitelisted_fields.is_a?(Symbol)
        whitelisted_fields = whitelisted_fields.split(',') if whitelisted_fields.is_a?(String)
        fields[type.to_s] = whitelisted_fields.map(&:to_sym)
      end

      # An internal-only structure that is passed through serializers as they are created.
      passthrough_options = {
        context: options[:context],
        serializer: options[:serializer],
        namespace: options[:namespace],
        include: includes,
        fields: fields,
        base_url: options[:base_url]
      }

      if !options[:skip_collection_check] && options[:is_collection] && !objects.respond_to?(:each)
        raise JSONAPI::Serializer::AmbiguousCollectionError.new(
          'Attempted to serialize a single object as a collection.')
      end

      # Automatically include linkage data for any relation that is also included.
      if includes
        include_linkages = includes.map { |key| key.to_s.split('.').first }
        passthrough_options[:include_linkages] = include_linkages
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
        primary_data = serialize_primary_multi(objects, passthrough_options)
      else
        # Duck-typing check for a collection being passed without is_collection true.
        # We always must be told if serializing a collection because the JSON:API spec distinguishes
        # how to serialize null single resources vs. empty collections.
        if !options[:skip_collection_check] && objects.respond_to?(:each)
          raise JSONAPI::Serializer::AmbiguousCollectionError.new(
            'Must provide `is_collection: true` to `serialize` when serializing collections.')
        end
        # Have single object.
        primary_data = serialize_primary(objects, passthrough_options)
      end
      result = {
        'data' => primary_data,
      }
      result['jsonapi'] = options[:jsonapi] if options[:jsonapi]
      result['meta'] = options[:meta] if options[:meta]
      result['links'] = options[:links] if options[:links]
      result['errors'] = options[:errors] if options[:errors]

      # If 'include' relationships are given, recursively find and include each object.
      if includes
        relationship_data = {}
        inclusion_tree = parse_relationship_paths(includes)

        # Given all the primary objects (either the single root object or collection of objects),
        # recursively search and find related associations that were specified as includes.
        objects = options[:is_collection] ? objects.to_a : [objects]
        objects.compact.each do |obj|
          # Use the mutability of relationship_data as the return datastructure to take advantage
          # of the internal special merging logic.
          find_recursive_relationships(obj, inclusion_tree, relationship_data, passthrough_options)
        end

        result['included'] = relationship_data.map do |_, data|
          included_passthrough_options = {}
          included_passthrough_options[:base_url] = passthrough_options[:base_url]
          included_passthrough_options[:context] = passthrough_options[:context]
          included_passthrough_options[:fields] = passthrough_options[:fields]
          included_passthrough_options[:serializer] = find_serializer_class(data[:object], options)
          included_passthrough_options[:namespace] = passthrough_options[:namespace]
          included_passthrough_options[:include_linkages] = data[:include_linkages]
          serialize_primary(data[:object], included_passthrough_options)
        end
      end
      result
    end

    def self.serialize_errors(raw_errors)
      if is_activemodel_errors?(raw_errors)
        {'errors' => activemodel_errors(raw_errors)}
      else
        {'errors' => raw_errors}
      end
    end

    def self.activemodel_errors(raw_errors)
      raw_errors.to_hash(full_messages: true).inject([]) do |result, (attribute, messages)|
        result += messages.map { |message| single_error(attribute.to_s, message) }
      end
    end

    def self.is_activemodel_errors?(raw_errors)
      raw_errors.respond_to?(:to_hash) && raw_errors.respond_to?(:full_messages)
    end

    def self.single_error(attribute, message)
      {
        'source' => {
          'pointer' => "/data/attributes/#{attribute.dasherize}"
        },
        'detail' => message
      }
    end

    def self.serialize_primary(object, options = {})
      serializer_class = options[:serializer] || find_serializer_class(object, options)

      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources.
      # http://jsonapi.org/format/#document-structure-top-level
      return if object.nil?

      serializer = serializer_class.new(object, options)
      data = {
        'type' => serializer.type.to_s,
      }

      # "The id member is not required when the resource object originates at the client
      #  and represents a new resource to be created on the server."
      # http://jsonapi.org/format/#document-resource-objects
      # We'll assume that if the id is blank, it means the resource is to be created.
      data['id'] = serializer.id.to_s if serializer.id && !serializer.id.empty?

      # Merge in optional top-level members if they are non-nil.
      # http://jsonapi.org/format/#document-structure-resource-objects
      # Call the methods once now to avoid calling them twice when evaluating the if's below.
      attributes = serializer.attributes
      links = serializer.links
      relationships = serializer.relationships
      jsonapi = serializer.jsonapi
      meta = serializer.meta
      data['attributes'] = attributes if !attributes.empty?
      data['links'] = links if !links.empty?
      data['relationships'] = relationships if !relationships.empty?
      data['jsonapi'] = jsonapi if !jsonapi.nil?
      data['meta'] = meta if !meta.nil?
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

    # Recursively find object relationships and returns a tree of related objects.
    # Example return:
    # {
    #   ['comments', '1'] => {object: <Comment>, include_linkages: ['author']},
    #   ['users', '1'] => {object: <User>, include_linkages: []},
    #   ['users', '2'] => {object: <User>, include_linkages: []},
    # }
    def self.find_recursive_relationships(root_object, root_inclusion_tree, results, options)
      root_inclusion_tree.each do |attribute_name, child_inclusion_tree|
        # Skip the sentinal value, but we need to preserve it for siblings.
        next if attribute_name == :_include

        serializer = JSONAPI::Serializer.find_serializer(root_object, options)
        unformatted_attr_name = serializer.unformat_name(attribute_name).to_sym

        # We know the name of this relationship, but we don't know where it is stored internally.
        # Check if it is a has_one or has_many relationship.
        object = nil
        is_collection = false
        is_valid_attr = false
        if serializer.has_one_relationships.has_key?(unformatted_attr_name)
          is_valid_attr = true
          attr_data = serializer.has_one_relationships[unformatted_attr_name]
          object = serializer.has_one_relationship(unformatted_attr_name, attr_data)
        elsif serializer.has_many_relationships.has_key?(unformatted_attr_name)
          is_valid_attr = true
          is_collection = true
          attr_data = serializer.has_many_relationships[unformatted_attr_name]
          object = serializer.has_many_relationship(unformatted_attr_name, attr_data)
        end

        if !is_valid_attr
          raise JSONAPI::Serializer::InvalidIncludeError.new(
            "'#{attribute_name}' is not a valid include.")
        end

        if attribute_name != serializer.format_name(attribute_name)
          expected_name = serializer.format_name(attribute_name)

          raise JSONAPI::Serializer::InvalidIncludeError.new(
            "'#{attribute_name}' is not a valid include.  Did you mean '#{expected_name}' ?"
          )
        end

        # We're finding relationships for compound documents, so skip anything that doesn't exist.
        next if object.nil?

        # Full linkage: a request for comments.author MUST automatically include comments
        # in the response.
        objects = is_collection ? object : [object]
        if child_inclusion_tree[:_include] == true
          # Include the current level objects if the _include attribute exists.
          # If it is not set, that indicates that this is an inner path and not a leaf and will
          # be followed by the recursion below.
          objects.each do |obj|
            obj_serializer = JSONAPI::Serializer.find_serializer(obj, options)
            # Use keys of ['posts', '1'] for the results to enforce uniqueness.
            # Spec: A compound document MUST NOT include more than one resource object for each
            # type and id pair.
            # http://jsonapi.org/format/#document-structure-compound-documents
            key = [obj_serializer.type, obj_serializer.id]

            # This is special: we know at this level if a child of this parent will also been
            # included in the compound document, so we can compute exactly what linkages should
            # be included by the object at this level. This satisfies this part of the spec:
            #
            # Spec: Resource linkage in a compound document allows a client to link together
            # all of the included resource objects without having to GET any relationship URLs.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            current_child_includes = []
            inclusion_names = child_inclusion_tree.keys.reject { |k| k == :_include }
            inclusion_names.each do |inclusion_name|
              if child_inclusion_tree[inclusion_name][:_include]
                current_child_includes << inclusion_name
              end
            end

            # Special merge: we might see this object multiple times in the course of recursion,
            # so merge the include_linkages each time we see it to load all the relevant linkages.
            current_child_includes += results[key] && results[key][:include_linkages] || []
            current_child_includes.uniq!
            results[key] = {object: obj, include_linkages: current_child_includes}
          end
        end

        # Recurse deeper!
        if !child_inclusion_tree.empty?
          # For each object we just loaded, find all deeper recursive relationships.
          objects.each do |obj|
            find_recursive_relationships(obj, child_inclusion_tree, results, options)
          end
        end
      end
      nil
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
      data[current_level] ||= {_include: true}

      if parts.length == 2
        # Need to recurse more.
        merge_relationship_path(parts[1], data[current_level])
      end
    end
    class << self; protected :merge_relationship_path; end
  end
end
