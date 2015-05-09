module MyApp
  class Post
    attr_accessor :id
    attr_accessor :title
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

    # has_one :author, serializer: :user
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
