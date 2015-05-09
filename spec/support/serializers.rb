module MyApp
  class Post
    attr_accessor :id
    attr_accessor :title
    attr_accessor :body
    attr_accessor :author
    attr_accessor :comments
  end

  class Comment
    attr_accessor :id
    attr_accessor :body
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
    has_many :comments
  end

  class SimplestPostSerializer
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    def type
      'posts'
    end
  end

  class PostSerializerWithMetadata
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    def type
      'posts'
    end

    def meta
      {
        'copyright' => 'Copyright 2015 Example Corp.',
        'authors' => [
          'Aliens'
        ]
      }
    end
  end

  class CommentSerializer
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
end
