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

  class UserSerializer
    include JSONAPI::Serializer

    attribute :name
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

  class PostSerializerWithContextHandling < SimplestPostSerializer
    include JSONAPI::Serializer

    attribute :body, if: :show_body?, unless: :hide_body?

    def show_body?
      context.fetch(:show_body, true)
    end

    def hide_body?
      context.fetch(:hide_body, false)
    end
  end
end
