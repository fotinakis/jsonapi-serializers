module MyApp
  class Post
    attr_accessor :id
    attr_accessor :title
    attr_accessor :body
    attr_accessor :author
    attr_accessor :long_comments
  end

  class TaggedPost
    attr_accessor :id
    attr_accessor :title
    attr_accessor :body
    attr_accessor :tag
    attr_accessor :author
    attr_accessor :long_comments
  end

  class LongComment
    attr_accessor :id
    attr_accessor :body
    attr_accessor :user
    attr_accessor :post

    # Just a copy of the default implementation, we need this to exist to be able to stub in tests.
    def jsonapi_serializer_class_name
      'MyApp::LongCommentSerializer'
    end
  end

  class User
    attr_accessor :id
    attr_accessor :name

    def jsonapi_serializer_class_name
      'MyAppOtherNamespace::UserSerializer'
    end
  end

  class UnderscoreTest
    attr_accessor :id

    def tagged_posts
      []
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

  class UnderscoreTestSerializer
    include JSONAPI::Serializer

    has_many :tagged_posts

    def format_name(attribute_name)
      attribute_name.to_s.underscore
    end
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

  class PostSerializerWithoutIncludeLinks
    include JSONAPI::Serializer

    attribute :title

    has_one :author, include_links: false
    has_many :long_comments, include_links: false

    def type
      :posts
    end
  end

  class PostSerializerWithIncludeData
    include JSONAPI::Serializer

    attribute :title

    has_one :author, include_data: true
    has_many :long_comments, include_data: true

    def type
      :posts
    end
  end

  class PostSerializerWithContext < PostSerializer
    attribute :body, if: :show_body?, unless: :hide_body?

    def show_body?
      context.fetch(:show_body, true)
    end

    def hide_body?
      context.fetch(:hide_body, false)
    end
  end

  class LongCommentsSerializerWithContext
    include JSONAPI::Serializer

    attribute :body, if: :show_body?
    has_one :user, if: :show_comments_user?

    def show_body?
      context.fetch(:show_body, true)
    end

    def show_comments_user?
      context.fetch(:show_comments_user, true)
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

    def self_link
      nil
    end

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

  class MultipleAttributesSerializer
    include JSONAPI::Serializer

    attributes :title, :body
  end

  class PostSerializerWithInheritedProperties < PostSerializer
    # Add only :tag, inherit the rest.
    attribute :tag
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

module Api
  module V1
    module MyApp
      class UserSerializer
        include JSONAPI::Serializer

        attribute :name
      end

      class PostSerializer
        include JSONAPI::Serializer

        attribute :title

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
    end
  end
end
