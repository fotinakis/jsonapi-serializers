describe JSONAPI::Serializer do
  describe 'internal-only serialize_primary' do
    it 'serializes nil to nil' do
      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources
      # http://jsonapi.org/format/#document-structure-top-level
      expect(MyApp::PostSerializer.send(:serialize_primary, nil)).to be_nil
    end
    it 'can serialize a simple object' do
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
    it 'can serialize a simple object with resource-level metadata' do
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
    it 'can serialize a null to-one relationship' do
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
          'comments' => {
            'self' => '/posts/1/links/comments',
            'related' => '/posts/1/comments',
            'linkage' => [],
          },
        },
      })
    end
    it 'can serialize a simple to-one relationship' do
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
          'comments' => {
            'self' => '/posts/1/links/comments',
            'related' => '/posts/1/comments',
            'linkage' => [],
          },
        },
      })
    end
    it 'can serialize an empty to-many relationship' do
      post = create(:post, comments: [])

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
          'comments' => {
            'self' => '/posts/1/links/comments',
            'related' => '/posts/1/comments',
            # Spec: Resource linkage MUST be represented as one of the following:
            # - an empty array ([]) for empty to-many relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            'linkage' => [],
          },
        },
      })
    end
    it 'can serialize a simple to-many relationship' do
      comments = create_list(:comment, 2)
      post = create(:post, comments: comments)

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
          'comments' => {
            'self' => '/posts/1/links/comments',
            'related' => '/posts/1/comments',
            # Spec: Resource linkage MUST be represented as one of the following:
            # - an array of linkage objects for non-empty to-many relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            'linkage' => [
              {
                'type' => 'comments',
                'id' => '1',
              },
              {
                'type' => 'comments',
                'id' => '2',
              },
            ],
          },
        },
      })
    end
  end
  describe 'serialize' do
    it 'can serialize a nil object' do
     expect(MyApp::PostSerializer.serialize(nil)).to eq({'data' => nil})
    end
    it 'can serialize an empty array' do
     expect(MyApp::PostSerializer.serialize([])).to eq({'data' => []})
    end
    it 'correctly wraps primary data' do
      post = create(:post)
      primary_data = MyApp::PostSerializer.send(:serialize_primary, post)
      expect(MyApp::PostSerializer.serialize(post)).to eq({
        'data' => MyApp::PostSerializer.send(:serialize_primary, post),
      })
    end
    it 'handles include of nil to-one relationship in compound document' do
      post = create(:post)
      primary_data = MyApp::PostSerializer.send(:serialize_primary, post)

      expect(MyApp::PostSerializer.serialize(post, include: ['author'])).to eq({
        'data' => MyApp::PostSerializer.send(:serialize_primary, post),
        'included' => [],
      })
    end
    it 'handles include of simple to-one relationship in compound document' do
      post = create(:post, :with_author)
      expect(MyApp::PostSerializer.serialize(post, include: ['author'])).to eq({
        'data' => MyApp::PostSerializer.send(:serialize_primary, post),
        'included' => [
          MyApp::UserSerializer.send(:serialize_primary, post.author),
        ],
      })
    end
    it 'handles include of empty to-many relationships in compound document' do
      post = create(:post, :with_author, comments: [])
      expected_includes = MyApp::CommentSerializer.send(:serialize_primary_multi, post.comments)

      expect(MyApp::PostSerializer.serialize(post, include: ['comments'])).to eq({
        'data' => MyApp::PostSerializer.send(:serialize_primary, post),
        'included' => expected_includes,
      })
    end
    it 'handles include of simple to-many relationships in compound document' do
      comments = create_list(:comment, 2)
      post = create(:post, :with_author, comments: comments)
      expected_includes = MyApp::CommentSerializer.send(:serialize_primary_multi, post.comments)

      expect(MyApp::PostSerializer.serialize(post, include: ['comments'])).to eq({
        'data' => MyApp::PostSerializer.send(:serialize_primary, post),
        'included' => expected_includes,
      })
    end
  end
  describe 'internal-only parse_relationship_paths' do
    it 'correctly handles empty arrays' do
      result = MyApp::PostSerializer.send(:parse_relationship_paths, [])
      expect(result).to eq({})
    end
    it 'correctly handles single-level relationship paths' do
      result = MyApp::PostSerializer.send(:parse_relationship_paths, ['comments'])
      expect(result).to eq({'comments' => {'_include' => true}})
    end
    it 'correctly handles multi-level relationship paths' do
      result = MyApp::PostSerializer.send(:parse_relationship_paths, ['comments.user'])
      expect(result).to eq({'comments' => {'user' => {'_include' => true}}})
    end
    it 'correctly handles multi-level relationship paths with same parent' do
      result = MyApp::PostSerializer.send(:parse_relationship_paths, ['comments', 'comments.user'])
      expect(result).to eq({'comments' => {'_include' => true, 'user' => {'_include' => true}}})
    end
    it 'correctly handles mixed single and multi-level relationship paths' do
      paths = ['author', 'comments', 'comments.post.author']
      result = MyApp::PostSerializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'author' => {'_include' => true},
        'comments' => {'_include' => true, 'post' => {'author' => {'_include' => true}}},
      })
    end
  end
end