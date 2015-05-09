describe JSONAPI::Serializer do
  describe 'internal-only serialize_primary' do
    it 'serializes nil to nil' do
      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources
      # http://jsonapi.org/format/#document-structure-top-level
      expect(MyApp::PostSerializer.send(:serialize_primary, nil)).to be_nil
    end
    it 'can serialize primary data for a simple object' do
      post = create(:post)
      expect(MyApp::SimplestPostSerializer.send(:serialize_primary, post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => '/posts/1',
        },
      })
    end
    it 'can serialize primary data for a simple object with resource-level metadata' do
      post = create(:post)
      expect(MyApp::PostSerializerWithMetadata.send(:serialize_primary, post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => '/posts/1',
        },
        'meta' => {
          'copyright' => 'Copyright 2015 Example Corp.',
          'authors' => [
            'Aliens',
          ],
        },
      })
    end
    it 'can serialize primary data for a null to-one relationship' do
      post = create(:post, author: nil)
      expect(MyApp::PostSerializer.send(:serialize_primary, post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => '/posts/1',
          'author' => {
            'self' => '/posts/1/links/author',
            'related' => '/posts/1/author',
            # Spec: Resource linkage MUST be represented as one of the following:
            # - null for empty to-one relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            'linkage' => nil,
          },
          'long-comments' => {
            'self' => '/posts/1/links/long-comments',
            'related' => '/posts/1/long-comments',
            'linkage' => [],
          },
        },
      })
    end
    it 'can serialize primary data for a simple to-one relationship' do
      post = create(:post, :with_author)
      expect(MyApp::PostSerializer.send(:serialize_primary, post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => '/posts/1',
          'author' => {
            'self' => '/posts/1/links/author',
            'related' => '/posts/1/author',
            # Spec: Resource linkage MUST be represented as one of the following:
            # - a 'linkage object' (defined below) for non-empty to-one relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            'linkage' => {
              'type' => 'users',
              'id' => '1',
            },
          },
          'long-comments' => {
            'self' => '/posts/1/links/long-comments',
            'related' => '/posts/1/long-comments',
            'linkage' => [],
          },
        },
      })
    end
    it 'can serialize primary data for an empty to-many relationship' do
      post = create(:post, long_comments: [])

      expect(MyApp::PostSerializer.send(:serialize_primary, post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => '/posts/1',
          'author' => {
            'self' => '/posts/1/links/author',
            'related' => '/posts/1/author',
            'linkage' => nil,
          },
          'long-comments' => {
            'self' => '/posts/1/links/long-comments',
            'related' => '/posts/1/long-comments',
            # Spec: Resource linkage MUST be represented as one of the following:
            # - an empty array ([]) for empty to-many relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            'linkage' => [],
          },
        },
      })
    end
    it 'can serialize primary data for a simple to-many relationship' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, long_comments: long_comments)

      expect(MyApp::PostSerializer.send(:serialize_primary, post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => '/posts/1',
          'author' => {
            'self' => '/posts/1/links/author',
            'related' => '/posts/1/author',
            'linkage' => nil,
          },
          'long-comments' => {
            'self' => '/posts/1/links/long-comments',
            'related' => '/posts/1/long-comments',
            # Spec: Resource linkage MUST be represented as one of the following:
            # - an array of linkage objects for non-empty to-many relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            'linkage' => [
              {
                'type' => 'long-comments',
                'id' => '1',
              },
              {
                'type' => 'long-comments',
                'id' => '2',
              },
            ],
          },
        },
      })
    end
    it 'can serialize primary data for a simple object with a long name' do
      long_comment = create(:long_comment, post: create(:post))
      expect(MyApp::LongCommentSerializer.send(:serialize_primary, long_comment)).to eq({
        'id' => '1',
        'type' => 'long-comments',
        'attributes' => {
          'body' => 'Body for LongComment 1',
        },
        'links' => {
          'self' => '/long-comments/1',
          'user' => {
            'self' => '/long-comments/1/links/user',
            'related' => '/long-comments/1/user',
            'linkage' => nil,
          },
          'post' => {
            'self' => '/long-comments/1/links/post',
            'related' => '/long-comments/1/post',
            'linkage' => {
              'type' => 'posts',
              'id' => '1',
            },
          },
        },
      })
    end
  end

  def get_primary_data(object)
    is_multiple = object.respond_to?(:each)
    if is_multiple
      MyApp::PostSerializer.find_serializer_class(object[0]).send(:serialize_primary_multi, object)
    else
      MyApp::PostSerializer.find_serializer_class(object).send(:serialize_primary, object)
    end
  end

  describe 'serialize' do
    # The following tests rely on the fact that serialize_primary has been tested above, so object
    # primary data is not explicitly tested here. If things are broken, look above here first.

    it 'can serialize a nil object' do
     expect(MyApp::PostSerializer.serialize(nil)).to eq({'data' => nil})
    end
    it 'can serialize an empty array' do
     expect(MyApp::PostSerializer.serialize([])).to eq({'data' => []})
    end
    it 'can serialize a simple object' do
      post = create(:post)
      expect(MyApp::PostSerializer.serialize(post)).to eq({
        'data' => get_primary_data(post),
      })
    end
    it 'handles include of nil to-one relationship in compound document' do
      post = create(:post)

      expect(MyApp::PostSerializer.serialize(post, include: ['author'])).to eq({
        'data' => get_primary_data(post),
        'included' => [],
      })
    end
    it 'handles include of simple to-one relationship in compound document' do
      post = create(:post, :with_author)
      expect(MyApp::PostSerializer.serialize(post, include: ['author'])).to eq({
        'data' => get_primary_data(post),
        'included' => [
          get_primary_data(post.author),
        ],
      })
    end
    it 'handles include of empty to-many relationships in compound document' do
      post = create(:post, :with_author, long_comments: [])
      expect(MyApp::PostSerializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => get_primary_data(post),
        'included' => [],
      })
    end
    it 'handles include of simple to-many relationships in compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)

      expect(MyApp::PostSerializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => get_primary_data(post),
        'included' => get_primary_data(post.long_comments),
      })
    end
    it 'handles circular-referencing relationships in compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)
      long_comments.each { |c| c.post = post }

      expect(MyApp::PostSerializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => get_primary_data(post),
        'included' => get_primary_data(post.long_comments),
      })
    end
  end
  describe 'internal-only parse_relationship_paths' do
    it 'correctly handles empty arrays' do
      result = MyApp::PostSerializer.send(:parse_relationship_paths, [])
      expect(result).to eq({})
    end
    it 'correctly handles single-level relationship paths' do
      result = MyApp::PostSerializer.send(:parse_relationship_paths, ['long-comments'])
      expect(result).to eq({
        'long-comments' => {'_include' => true}
      })
    end
    it 'correctly handles multi-level relationship paths' do
      result = MyApp::PostSerializer.send(:parse_relationship_paths, ['long-comments.user'])
      expect(result).to eq({
        'long-comments' => {'user' => {'_include' => true}}
      })
    end
    it 'correctly handles multi-level relationship paths with same parent' do
      paths = ['long-comments', 'long-comments.user']
      result = MyApp::PostSerializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'long-comments' => {'_include' => true, 'user' => {'_include' => true}}
      })
    end
    it 'correctly handles mixed single and multi-level relationship paths' do
      paths = ['author', 'long-comments', 'long-comments.post.author']
      result = MyApp::PostSerializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'author' => {'_include' => true},
        'long-comments' => {'_include' => true, 'post' => {'author' => {'_include' => true}}},
      })
    end
  end
end