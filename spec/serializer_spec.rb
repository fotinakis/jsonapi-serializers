describe JSONAPI::Serializer do
  def serialize_primary(object, options = {})
    # Note: intentional high-coupling to protected method for tests.
    JSONAPI::Serializer.send(:serialize_primary, object, options)
  end

  describe 'internal-only serialize_primary' do
    it 'serializes nil to nil' do
      # Spec: Primary data MUST be either:
      # - a single resource object or null, for requests that target single resources
      # http://jsonapi.org/format/#document-structure-top-level
      primary_data = serialize_primary(nil, {serializer: MyApp::PostSerializer})
      expect(primary_data).to be_nil
    end
    it 'can serialize primary data for a simple object' do
      post = create(:post)
      primary_data = serialize_primary(post, {serializer: MyApp::SimplestPostSerializer})
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
    it 'can serialize primary data for a simple object with a long name' do
      long_comment = create(:long_comment, post: create(:post))
      primary_data = serialize_primary(long_comment, {serializer: MyApp::LongCommentSerializer})
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
          },
          'post' => {
            'self' => '/long-comments/1/links/post',
            'related' => '/long-comments/1/post',
          },
        },
      })
    end
    it 'can serialize primary data for a simple object with resource-level metadata' do
      post = create(:post)
      primary_data = serialize_primary(post, {serializer: MyApp::PostSerializerWithMetadata})
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
    context 'without any linkage includes (default)' do
      it 'can serialize primary data for an object with to-one and to-many relationships' do
        post = create(:post)
        primary_data = serialize_primary(post, {serializer: MyApp::PostSerializer})
        expect(primary_data).to eq({
          'id' => '1',
          'type' => 'posts',
          'attributes' => {
            'title' => 'Title for Post 1',
            'long-content' => 'Body for Post 1',
          },
          'links' => {
            'self' => '/posts/1',
            # Both to-one and to-many links are present, but neither include linkage:
            'author' => {
              'self' => '/posts/1/links/author',
              'related' => '/posts/1/author',
            },
            'long-comments' => {
              'self' => '/posts/1/links/long-comments',
              'related' => '/posts/1/long-comments',
            },
          },
        })
      end
    end
    context 'with linkage includes' do
      it 'can serialize primary data for a null to-one relationship' do
        post = create(:post, author: nil)
        options = {
          serializer: MyApp::PostSerializer,
          include_linkages: ['author', 'long-comments'],
        }
        primary_data = serialize_primary(post, options)
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
        options = {
          serializer: MyApp::PostSerializer,
          include_linkages: ['author', 'long-comments'],
        }
        primary_data = serialize_primary(post, options)
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
        options = {
          serializer: MyApp::PostSerializer,
          include_linkages: ['author', 'long-comments'],
        }
        primary_data = serialize_primary(post, options)
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
        options = {
          serializer: MyApp::PostSerializer,
          include_linkages: ['author', 'long-comments'],
        }
        primary_data = serialize_primary(post, options)
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
    end
  end

  describe 'JSONAPI::Serializer.serialize' do
    # The following tests rely on the fact that serialize_primary has been tested above, so object
    # primary data is not explicitly tested here. If things are broken, look above here first.

    it 'can serialize a nil object' do
      expect(JSONAPI::Serializer.serialize(nil)).to eq({'data' => nil})
    end
    it 'can serialize a nil object with includes' do
      data = JSONAPI::Serializer.serialize(nil, include: ['fake'])
      expect(data).to eq({'data' => nil, 'included' => []})
    end
    it 'can serialize an empty array' do
      data = JSONAPI::Serializer.serialize([], is_collection: true, include: ['fake'])
      expect(data).to eq({'data' => [], 'included' => []})
    end
    it 'can serialize a simple object' do
      post = create(:post)
      expect(JSONAPI::Serializer.serialize(post)).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
      })
    end
    it 'can serialize a collection' do
      posts = create_list(:post, 2)
      expect(JSONAPI::Serializer.serialize(posts, is_collection: true)).to eq({
        'data' => [
          serialize_primary(posts.first, {serializer: MyApp::PostSerializer}),
          serialize_primary(posts.last, {serializer: MyApp::PostSerializer}),
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
        'data' => serialize_primary(post, {serializer: MyApp::SimplestPostSerializer}),
      })
    end
    it 'handles include of nil to-one relationship in compound document' do
      post = create(:post)

      expect(JSONAPI::Serializer.serialize(post, include: ['author'])).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [],
      })
    end
    it 'handles include of simple to-one relationship in compound document' do
      post = create(:post, :with_author)
      expect(JSONAPI::Serializer.serialize(post, include: ['author'])).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [
          serialize_primary(post.author, {serializer: MyApp::UserSerializer}),
        ],
      })
    end
    it 'handles include of empty to-many relationships in compound document' do
      post = create(:post, :with_author, long_comments: [])
      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [],
      })
    end
    it 'handles include of simple to-many relationships in compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)

      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [
          serialize_primary(long_comments.first, {serializer: MyApp::LongCommentSerializer}),
          serialize_primary(long_comments.last, {serializer: MyApp::LongCommentSerializer}),
        ],
      })
    end
    it 'only includes one copy of each referenced relationship' do
      long_comment = create(:long_comment)
      long_comments = [long_comment, long_comment]
      post = create(:post, :with_author, long_comments: long_comments)

      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [
          serialize_primary(long_comment, {serializer: MyApp::LongCommentSerializer}),
        ],
      })
    end
    it 'handles circular-referencing relationships in compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)

      # Make sure each long-comment has a circular reference back to the post.
      long_comments.each { |c| c.post = post }

      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [
          serialize_primary(post.long_comments.first, {serializer: MyApp::LongCommentSerializer}),
          serialize_primary(post.long_comments.last, {serializer: MyApp::LongCommentSerializer}),
        ],
      })
    end
    it 'errors if include is not a defined attribute' do
      user = create(:user)
      expect { JSONAPI::Serializer.serialize(user, include: ['fake-attr']) }.to raise_error
    end
    it 'handles recursive loading of relationships' do
      user = create(:user)
      long_comments = create_list(:long_comment, 2, user: user)
      post = create(:post, :with_author, long_comments: long_comments)
      # Make sure each long-comment has a circular reference back to the post.
      long_comments.each { |c| c.post = post }

      expected_data = {
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [
          # Only the author is included:
          serialize_primary(post.author, {serializer: MyApp::UserSerializer}),
        ],
      }

      includes = ['long-comments.post.author']
      actual_data = JSONAPI::Serializer.serialize(post, include: ['long-comments.post.author'])
      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end
    it 'handles recursive loading of multiple to-one relationships' do
      first_user = create(:user)
      second_user = create(:user)
      first_comment = create(:long_comment, user: first_user)
      second_comment = create(:long_comment, user: second_user)
      long_comments = [first_comment, second_comment]
      post = create(:post, :with_author, long_comments: long_comments)
      # Make sure each long-comment has a circular reference back to the post.
      long_comments.each { |c| c.post = post }

      expected_data = {
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [
          serialize_primary(first_user, {serializer: MyApp::UserSerializer}),
          serialize_primary(second_user, {serializer: MyApp::UserSerializer}),
        ],
      }
      includes = ['long-comments.user']
      actual_data = JSONAPI::Serializer.serialize(post, include: includes)

      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end
    it 'handles recursive loading of to-many relationships with overlapping include paths' do
      user = create(:user)
      long_comments = create_list(:long_comment, 2, user: user)
      post = create(:post, :with_author, long_comments: long_comments)
      # Make sure each long-comment has a circular reference back to the post.
      long_comments.each { |c| c.post = post }

      expected_data = {
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
        'included' => [
          serialize_primary(long_comments.first, {serializer: MyApp::LongCommentSerializer}),
          serialize_primary(long_comments.last, {serializer: MyApp::LongCommentSerializer}),
          serialize_primary(post.author, {serializer: MyApp::UserSerializer}),
        ],
      }
      # Also test that it handles string include arguments.
      includes = 'long-comments, long-comments.post.author'
      actual_data = JSONAPI::Serializer.serialize(post, include: includes)

      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end
  end

  describe 'serialize (class method)' do
    it 'delegates to module method but overrides serializer' do
      post = create(:post)
      expect(MyApp::SimplestPostSerializer.serialize(post)).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::SimplestPostSerializer}),
      })
    end
  end

  describe 'internal-only parse_relationship_paths' do
    it 'correctly handles empty arrays' do
      result = JSONAPI::Serializer.send(:parse_relationship_paths, [])
      expect(result).to eq({})
    end
    it 'correctly handles single-level relationship paths' do
      result = JSONAPI::Serializer.send(:parse_relationship_paths, ['foo'])
      expect(result).to eq({
        'foo' => {_include: true}
      })
    end
    it 'correctly handles multi-level relationship paths' do
      result = JSONAPI::Serializer.send(:parse_relationship_paths, ['foo.bar'])
      expect(result).to eq({
        'foo' => {'bar' => {_include: true}}
      })
    end
    it 'correctly handles multi-level relationship paths with same parent' do
      paths = ['foo', 'foo.bar']
      result = JSONAPI::Serializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'foo' => {_include: true, 'bar' => {_include: true}}
      })
    end
    it 'correctly handles multi-level relationship paths with different parent' do
      paths = ['foo', 'bar', 'bar.baz']
      result = JSONAPI::Serializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'foo' => {_include: true},
        'bar' => {_include: true, 'baz' => {_include: true}},
      })
    end
    it 'correctly handles three-leveled path' do
      paths = ['foo', 'foo.bar', 'foo.bar.baz']
      result = JSONAPI::Serializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'foo' => {_include: true, 'bar' => {_include: true, 'baz' => {_include: true}}}
      })
    end
    it 'correctly handles three-leveled path with skipped middle' do
      paths = ['foo', 'foo.bar.baz']
      result = JSONAPI::Serializer.send(:parse_relationship_paths, paths)
      expect(result).to eq({
        'foo' => {_include: true, 'bar' => {'baz' => {_include: true}}}
      })
    end
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
  describe 'context' do
    xit 'is correctly passed through all serializers' do
    end
  end
end