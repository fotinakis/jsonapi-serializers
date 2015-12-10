module MyApp
  class Post
    attr_accessor :id
    attr_accessor :title
    attr_accessor :body
    attr_accessor :author
    attr_accessor :long_comments
  end

  class LongComment
    attr_accessor :id
    attr_accessor :body
    attr_accessor :user
    attr_accessor :post
  end

  class User
    attr_accessor :id
    attr_accessor :name

    def jsonapi_serializer_class_name
      'MyAppOtherNamespace::UserSerializer'
    end
  end

  class PostSerializer
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    has_one :author
    has_many :long_comments
  end

  class LongCommentSerializer
    include JSONAPI::Serializer

    attribute :body
    has_one :user

    # Circular-reference back to post.
    has_one :post
  end

  # More customized, one-off serializers to test particular behaviors:

  class SimplestPostSerializer
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    def type
      :posts
    end
  end

  class PostSerializerWithMetadata
    include JSONAPI::Serializer
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    def type
      'posts'  # Intentionally test string type.
    end

    def meta
      {
        'copyright' => 'Copyright 2015 Example Corp.',
        'authors' => ['Aliens'],
      }
    end
  end

  class PostSerializerWithContextHandling < SimplestPostSerializer
    attribute :body, if: :show_body?, unless: :hide_body?

    def show_body?
      context.fetch(:show_body, true)
    end

    def hide_body?
      context.fetch(:hide_body, false)
    end
  end

  class PostSerializerWithoutLinks
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    has_one :author
    has_many :long_comments

    def relationship_self_link(attribute_name)
      nil
    end

    def relationship_related_link(attribute_name)
      nil
    end
  end

  class PostSerializerWithBaseUrl
    include JSONAPI::Serializer

    def base_url
      'http://example.com'
    end

    attribute :title
    attribute :long_content do
      object.body
    end

    has_one :author
    has_many :long_comments
  end

  class EmptySerializer
    include JSONAPI::Serializer
  end
end

# Test the `jsonapi_serializer_class_name` override method for serializers in different namespaces.
# There is no explicit test for this, just implicit tests that correctly serialize User objects.
module MyAppOtherNamespace
  class UserSerializer
    include JSONAPI::Serializer

    attribute :name
  end
end