module MyApp
  class Post
    attr_accessor :id
    attr_accessor :title
    attr_accessor :body
    attr_accessor :author
  end

  class Comment
    attr_accessor :id
    attr_accessor :body
  end

  class User
    attr_accessor :id
    attr_accessor :name
  end

  class SimplePostSerializer
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    def type
      'posts'
    end
  end

  class PostSerializer
    include JSONAPI::Serializer

    attribute :title
    attribute :long_content do
      object.body
    end

    has_one :author
    # has_many :comments
  end


  class CommentSerializer
    include JSONAPI::Serializer

    attribute :body

    # has_one :user
  end

  class UserSerializer
    include JSONAPI::Serializer

    attribute :name

    # has_many :posts
    # has_many :comments
  end
end
