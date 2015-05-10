describe JSONAPI::Serializer do
  describe 'internal-only serialize_primary' do
    it 'serializes nil to nil' do
      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources
      # http://jsonapi.org/format/#document-structure-top-level
      primary_data = JSONAPI::Serializer.send(:serialize_primary, nil, MyApp::PostSerializer)
      expect(primary_data).to be_nil
    end
    it 'can serialize primary data for a simple object' do
      post = create(:post)
      serializer_class = MyApp::SimplestPostSerializer
      primary_data = JSONAPI::Serializer.send(:serialize_primary, post, serializer_class)
      expect(primary_data).to eq({
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
      serializer_class = MyApp::PostSerializerWithMetadata
      primary_data = JSONAPI::Serializer.send(:serialize_primary, post, serializer_class)
      expect(primary_data).to eq({
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
      serializer_class = MyApp::PostSerializer
      primary_data = JSONAPI::Serializer.send(:serialize_primary, post, serializer_class)
      expect(primary_data).to eq({
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
      serializer_class = MyApp::PostSerializer
      primary_data = JSONAPI::Serializer.send(:serialize_primary, post, serializer_class)
      expect(primary_data).to eq({
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
      serializer_class = MyApp::PostSerializer
      primary_data = JSONAPI::Serializer.send(:serialize_primary, post, serializer_class)
      expect(primary_data).to eq({
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
      serializer_class = MyApp::PostSerializer
      primary_data = JSONAPI::Serializer.send(:serialize_primary, post, serializer_class)
      expect(primary_data).to eq({
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
      serializer_class = MyApp::LongCommentSerializer
      primary_data = JSONAPI::Serializer.send(:serialize_primary, long_comment, serializer_class)
      expect(primary_data).to eq({
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

  def get_primary_data(object, serializer_class)
    JSONAPI::Serializer.send(:serialize_primary, object, serializer_class)
  end

  describe 'JSONAPI::Serializer.serialize' do
    # The following tests rely on the fact that serialize_primary has been tested above, so object
    # primary data is not explicitly tested here. If things are broken, look above here first.

    it 'can serialize a nil object' do
     expect(JSONAPI::Serializer.serialize(nil)).to eq({'data' => nil})
    end
    it 'can serialize an empty array' do
     expect(JSONAPI::Serializer.serialize([], is_collection: true)).to eq({'data' => []})
    end
    it 'can serialize a simple object' do
      post = create(:post)
      expect(JSONAPI::Serializer.serialize(post)).to eq({
        'data' => get_primary_data(post, MyApp::PostSerializer),
      })
    end
    it 'can serialize a collection' do
      posts = create_list(:post, 2)
      expect(JSONAPI::Serializer.serialize(posts, is_collection: true)).to eq({
        'data' => [
          get_primary_data(posts.first, MyApp::PostSerializer),
          get_primary_data(posts.last, MyApp::PostSerializer),
        ],
      })
    end
    it 'raises AmbiguousCollectionError if is_collection is not passed' do
      posts = create_list(:post, 2)
      error = JSONAPI::Serializers::AmbiguousCollectionError
      expect { JSONAPI::Serializer.serialize(posts) }.to raise_error(error)
    end
    it 'can serialize a nil object when given serializer' do
      options = {serializer: MyApp::PostSerializer}
      expect(JSONAPI::Serializer.serialize(nil, options)).to eq({'data' => nil})
    end
    it 'can serialize an empty array when given serializer' do
      options = {is_collection: true, serializer: MyApp::PostSerializer}
      expect(JSONAPI::Serializer.serialize([], options)).to eq({'data' => []})
    end
    it 'can serialize a simple object when given serializer' do
      post = create(:post)
      options = {serializer: MyApp::SimplestPostSerializer}
      expect(JSONAPI::Serializer.serialize(post, options)).to eq({
        'data' => get_primary_data(post, MyApp::SimplestPostSerializer),
      })
    end
    it 'handles include of nil to-one relationship in compound document' do
      post = create(:post)

      expect(JSONAPI::Serializer.serialize(post, include: ['author'])).to eq({
        'data' => get_primary_data(post, MyApp::PostSerializer),
        'included' => [],
      })
    end
    it 'handles include of simple to-one relationship in compound document' do
      post = create(:post, :with_author)
      expect(JSONAPI::Serializer.serialize(post, include: ['author'])).to eq({
        'data' => get_primary_data(post, MyApp::PostSerializer),
        'included' => [
          get_primary_data(post.author, MyApp::UserSerializer),
        ],
      })
    end
    it 'handles include of empty to-many relationships in compound document' do
      post = create(:post, :with_author, long_comments: [])
      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => get_primary_data(post, MyApp::PostSerializer),
        'included' => [],
      })
    end
    it 'handles include of simple to-many relationships in compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)

      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => get_primary_data(post, MyApp::PostSerializer),
        'included' => [
          get_primary_data(post.long_comments.first, MyApp::LongCommentSerializer),
          get_primary_data(post.long_comments.last, MyApp::LongCommentSerializer),
        ],
      })
    end
    it 'handles circular-referencing relationships in compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)
      long_comments.each { |c| c.post = post }

      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => get_primary_data(post, MyApp::PostSerializer),
        'included' => [
          get_primary_data(post.long_comments.first, MyApp::LongCommentSerializer),
          get_primary_data(post.long_comments.last, MyApp::LongCommentSerializer),
        ],
      })
    end
    xit 'handles recursive loading of relationships' do
    end
  end

  describe 'serialize (class method)' do
    it 'delegates to module method but overrides serializer' do
      post = create(:post)
      expect(MyApp::SimplestPostSerializer.serialize(post)).to eq({
        'data' => get_primary_data(post, MyApp::SimplestPostSerializer),
      })
    end
  end

  describe 'internal-only parse_relationship_paths' do
    it 'correctly handles empty arrays' do
      result = JSONAPI::Serializer.send(:parse_relationship_paths, [])
      expect(result).to eq({})
    end
    it 'correctly handles single-level relationship paths' do
      result = JSONAPI::Serializer.send(:parse_relationship_paths, ['long-comments'])
      expect(result).to eq({
        'long-comments' => {'_include' => true}
      })
    end
    it 'correctly handles multi-level relationship paths' do
      result = JSONAPI::Serializer.send(:parse_relationship_paths, ['long-comments.user'])
      expect(result).to eq({
        'long-comments' => {'user' => {'_include' => true}}
      })
    end
    it 'correctly handles multi-level relationship paths with same parent' do
      paths = ['long-comments', 'long-comments.user']
      result = JSONAPI::Serializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'long-comments' => {'_include' => true, 'user' => {'_include' => true}}
      })
    end
    it 'correctly handles mixed single and multi-level relationship paths' do
      paths = ['author', 'long-comments', 'long-comments.post.author']
      result = JSONAPI::Serializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'author' => {'_include' => true},
        'long-comments' => {'_include' => true, 'post' => {'author' => {'_include' => true}}},
      })
    end
    it 'accepts and parses string arguments' do
      paths = 'author, long-comments,long-comments.post.author'
      result = JSONAPI::Serializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'author' => {'_include' => true},
        'long-comments' => {'_include' => true, 'post' => {'author' => {'_include' => true}}},
      })
    end

    describe 'if/unless handling with contexts' do
      it 'can be used to show/hide attributes' do
        post = create(:post)
        options = {serializer: MyApp::PostSerializerWithContextHandling}

        options[:context] = {show_body: false}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to_not have_key('body')

        options[:context] = {show_body: true}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to have_key('body')
        expect(data['data']['attributes']['body']).to eq('Body for Post 1')

        options[:context] = {hide_body: true}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to_not have_key('body')

        options[:context] = {hide_body: false}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to have_key('body')
        expect(data['data']['attributes']['body']).to eq('Body for Post 1')

        options[:context] = {show_body: false, hide_body: false}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to_not have_key('body')

        options[:context] = {show_body: true, hide_body: false}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to have_key('body')
        expect(data['data']['attributes']['body']).to eq('Body for Post 1')

        # Remember: attribute is configured as if: show_body?, unless: hide_body?
        # and the results should be logically AND'd together:
        options[:context] = {show_body: false, hide_body: true}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to_not have_key('body')

        options[:context] = {show_body: true, hide_body: true}
        data = JSONAPI::Serializer.serialize(post, options)
        expect(data['data']['attributes']).to_not have_key('body')
      end
    end
  end
end