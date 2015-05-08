module MyApp
  class PostSerializer
    include JSONAPI::Serializer

    attribute :id
    attribute :title

    # has_one :author, serializer: :user
    # has_many :comments
  end


  class CommentSerializer
    include JSONAPI::Serializer

    attribute :id
    attribute :body

    # has_one :user
  end

  class UserSerializer
    include JSONAPI::Serializer

    attribute :id
    attribute :name

    # has_many :posts
    # has_many :comments
  end
end
