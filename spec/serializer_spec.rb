require 'active_model/errors'
require 'active_model/naming'
require 'active_model/translation'

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
        },
        'relationships' => {
          'user' => {
            'links' => {
              'self' => '/long-comments/1/relationships/user',
              'related' => '/long-comments/1/user',
            },
          },
          'post' => {
            'links' => {
              'self' => '/long-comments/1/relationships/post',
              'related' => '/long-comments/1/post',
            },
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
          },
          'relationships' => {
            # Both to-one and to-many links are present, but neither include linkage:
            'author' => {
              'links' => {
                'self' => '/posts/1/relationships/author',
                'related' => '/posts/1/author',
              },
            },
            'long-comments' => {
              'links' => {
                'self' => '/posts/1/relationships/long-comments',
                'related' => '/posts/1/long-comments',
              },
            },
          },
        })
      end
      it 'does not include relationship links if relationship_{self_link,_related_link} are nil' do
        post = create(:post)
        primary_data = serialize_primary(post, {serializer: MyApp::PostSerializerWithoutLinks})
        expect(primary_data).to eq({
          'id' => '1',
          'type' => 'posts',
          'attributes' => {
            'title' => 'Title for Post 1',
            'long-content' => 'Body for Post 1',
          },
          # This is technically invalid since relationships MUST contain at least one of links,
          # data, or meta, but we leave that up to the user.
          'relationships' => {
            'author' => {},
            'long-comments' => {},
          },
        })
      end
      it 'does not include id when it is nil' do
        post = create(:post)
        post.id = nil
        primary_data = serialize_primary(post, {serializer: MyApp::PostSerializerWithoutLinks})
        expect(primary_data).to eq({
          'type' => 'posts',
          'attributes' => {
            'title' => 'Title for Post 1',
            'long-content' => 'Body for Post 1',
          },
          'relationships' => {
            'author' => {},
            'long-comments' => {},
          },
        })
      end
      it 'serializes object when multiple attributes are declared once' do
        post = create(:post)
        primary_data = serialize_primary(post, {serializer: MyApp::MultipleAttributesSerializer})
        expect(primary_data).to eq({
          'id' => '1',
          'type' => 'posts',
          'attributes' => {
            'title' => 'Title for Post 1',
            'body' => 'Body for Post 1',
          },
          'links' => {
            'self' => '/posts/1',
          }
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
          },
          'relationships' => {
            'author' => {
              'links' => {
                'self' => '/posts/1/relationships/author',
                'related' => '/posts/1/author',
              },
              # Spec: Resource linkage MUST be represented as one of the following:
              # - null for empty to-one relationships.
              # http://jsonapi.org/format/#document-structure-resource-relationships
              'data' => nil,
            },
            'long-comments' => {
              'links' => {
                'self' => '/posts/1/relationships/long-comments',
                'related' => '/posts/1/long-comments',
              },
              'data' => [],
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
          },
          'relationships' => {
            'author' => {
              'links' => {
                'self' => '/posts/1/relationships/author',
                'related' => '/posts/1/author',
              },
              # Spec: Resource linkage MUST be represented as one of the following:
              # - a 'linkage object' (defined below) for non-empty to-one relationships.
              # http://jsonapi.org/format/#document-structure-resource-relationships
              'data' => {
                'type' => 'users',
                'id' => '1',
              },
            },
            'long-comments' => {
              'links' => {
                'self' => '/posts/1/relationships/long-comments',
                'related' => '/posts/1/long-comments',
              },
              'data' => [],
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
          },
          'relationships' => {
            'author' => {
              'links' => {
                'self' => '/posts/1/relationships/author',
                'related' => '/posts/1/author',
              },
              'data' => nil,
            },
            'long-comments' => {
              'links' => {
                'self' => '/posts/1/relationships/long-comments',
                'related' => '/posts/1/long-comments',
              },
              # Spec: Resource linkage MUST be represented as one of the following:
              # - an empty array ([]) for empty to-many relationships.
              # http://jsonapi.org/format/#document-structure-resource-relationships
              'data' => [],
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
          },
          'relationships' => {
            'author' => {
              'links' => {
                'self' => '/posts/1/relationships/author',
                'related' => '/posts/1/author',
              },
              'data' => nil,
            },
            'long-comments' => {
              'links' => {
                'self' => '/posts/1/relationships/long-comments',
                'related' => '/posts/1/long-comments',
              },
              # Spec: Resource linkage MUST be represented as one of the following:
              # - an array of linkage objects for non-empty to-many relationships.
              # http://jsonapi.org/format/#document-structure-resource-relationships
              'data' => [
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
    it 'can serialize primary data for an empty serializer with no attributes' do
      post = create(:post)
      primary_data = serialize_primary(post, {serializer: MyApp::EmptySerializer})
      expect(primary_data).to eq({
        'id' => '1',
        'type' => 'posts',
        'links' => {
          'self' => '/posts/1',
        },
      })
    end
    it 'can find the correct serializer by object class name' do
      post = create(:post)
      primary_data = serialize_primary(post)
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
        'relationships' => {
          'author' => {
            'links' => {
              'self' => '/posts/1/relationships/author',
              'related' => '/posts/1/author',
            },
          },
          'long-comments' => {
            'links' => {
              'self' => '/posts/1/relationships/long-comments',
              'related' => '/posts/1/long-comments',
            },
          },
        },
      })
    end

    it 'allows to exclude linkages for relationships' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)
      primary_data = serialize_primary(post, { serializer: MyApp::PostSerializerWithoutIncludeLinks })
      expect(primary_data).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1'
        },
        'links' => {
          'self' => '/posts/1',
        },
        'relationships' => {
          'author' => {
          },
          'long-comments' => {
          },
        }
      })
    end

    it 'allows to include data for relationships' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)
      primary_data = serialize_primary(post, { serializer: MyApp::PostSerializerWithIncludeData })
      expect(primary_data).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1'
        },
        'links' => {
          'self' => '/posts/1',
        },
        'relationships' => {
          'author' => {
            'links' => {
              'self' => '/posts/1/relationships/author',
              'related' => '/posts/1/author'
            },
            'data' => {
              'type' => 'users',
              'id' => '1'
            }
          },
          'long-comments' => {
            'links' => {
              'self' => '/posts/1/relationships/long-comments',
              'related' => '/posts/1/long-comments'
            },
            'data' => [
              {
                'type' => 'long-comments',
                'id' => '1'
              },
              {
                'type' => 'long-comments',
                'id' => '2'
              }
            ]
          },
        }
      })
    end
  end

  # The members data and errors MUST NOT coexist in the same document.
  describe 'JSONAPI::Serializer.serialize_errors' do
    it 'can include a top level errors node' do
      errors = [
        {
          'source' => {'pointer' => '/data/attributes/first-name'},
          'title' => 'Invalid Attribute',
          'detail' => 'First name must contain at least three characters.'
        },
        {
          'source' => {'pointer' => '/data/attributes/first-name'},
          'title' => 'Invalid Attribute',
          'detail' => 'First name must contain an emoji.'
        }
      ]
      expect(JSONAPI::Serializer.serialize_errors(errors)).to eq({'errors' => errors})
    end

    it 'works for active_record' do
      # DummyUser exists so we can test calling user.errors.to_hash(full_messages: true)
      class DummyUser
        extend ActiveModel::Naming
        extend ActiveModel::Translation

        def initialize
          @errors = ActiveModel::Errors.new(self)
          @errors.add(:email, :invalid, message: 'is invalid')
          @errors.add(:email, :blank, message: "can't be blank")
          @errors.add(:first_name, :blank, message: "can't be blank")
        end

        attr_accessor :first_name, :email
        attr_reader :errors

        def read_attribute_for_validation(attr)
          send(attr)
        end
      end
      user = DummyUser.new
      jsonapi_errors = [
        {
          'source' => {'pointer' => '/data/attributes/email'},
          'detail' => 'Email is invalid'
        },
        {
          'source' => {'pointer' => '/data/attributes/email'},
          'detail' => "Email can't be blank"
        },
        {
          'source' => {'pointer' => '/data/attributes/first-name'},
          'detail' => "First name can't be blank"
        }
      ]
      expect(JSONAPI::Serializer.serialize_errors(user.errors)).to eq({
        'errors' => jsonapi_errors,
      })
    end
  end

  describe 'JSONAPI::Serializer.serialize' do
    # The following tests rely on the fact that serialize_primary has been tested above, so object
    # primary data is not explicitly tested here. If things are broken, look above here first.

    it 'can serialize a nil object' do
      expect(JSONAPI::Serializer.serialize(nil)).to eq({'data' => nil})
    end
    it 'can serialize a nil object with includes' do
      # Also, the include argument is not validated in this case because we don't know the type.
      data = JSONAPI::Serializer.serialize(nil, include: ['fake'])
      expect(data).to eq({'data' => nil, 'included' => []})
    end
    it 'can serialize an empty array' do
      # Also, the include argument is not validated in this case because we don't know the type.
      data = JSONAPI::Serializer.serialize([], is_collection: true, include: ['fake'])
      expect(data).to eq({'data' => [], 'included' => []})
    end
    it 'can serialize a simple object' do
      post = create(:post)
      expect(JSONAPI::Serializer.serialize(post)).to eq({
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
      })
    end
    it 'can include a top level jsonapi node' do
      post = create(:post)
      jsonapi_version = {'version' => '1.0'}
      expect(JSONAPI::Serializer.serialize(post, jsonapi: jsonapi_version)).to eq({
        'jsonapi' => {'version' => '1.0'},
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
      })
    end
    it 'can include a top level meta node' do
      post = create(:post)
      meta = {authors: ['Yehuda Katz', 'Steve Klabnik'], copyright: 'Copyright 2015 Example Corp.'}
      expect(JSONAPI::Serializer.serialize(post, meta: meta)).to eq({
        'meta' => meta,
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
      })
    end
    it 'can include a top level links node' do
      post = create(:post)
      links = {self: 'http://example.com/posts'}
      expect(JSONAPI::Serializer.serialize(post, links: links)).to eq({
        'links' => links,
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
      })
    end
    # TODO: remove this code on next major release
    it 'can include a top level errors node - deprecated' do
      post = create(:post)
      errors = [
        {
          "source" => { "pointer" => "/data/attributes/first-name" },
          "title" => "Invalid Attribute",
          "detail" => "First name must contain at least three characters."
        },
        {
          "source" => { "pointer" => "/data/attributes/first-name" },
          "title" => "Invalid Attribute",
          "detail" => "First name must contain an emoji."
        }
      ]
      expect(JSONAPI::Serializer.serialize(post, errors: errors)).to eq({
        'errors' => errors,
        'data' => serialize_primary(post, {serializer: MyApp::PostSerializer}),
      })
    end
    it 'can serialize a single object with an `each` method by passing skip_collection_check: true' do
      post = create(:post)
      post.define_singleton_method(:each) do
        "defining this just to defeat the duck-type check"
      end
      expect(JSONAPI::Serializer.serialize(post, skip_collection_check: true)).to eq({
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
      error = JSONAPI::Serializer::AmbiguousCollectionError
      expect { JSONAPI::Serializer.serialize(posts) }.to raise_error(error)
    end

    it 'raises error if include is not named correctly' do
      post = create(:post)
      error = JSONAPI::Serializer::InvalidIncludeError
      expect { JSONAPI::Serializer.serialize(post, include: ['long_comments']) }.to raise_error(error)
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
    it 'handles include of nil to-one relationship with compound document' do
      post = create(:post)

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['author'],
      })
      expect(JSONAPI::Serializer.serialize(post, include: ['author'])).to eq({
        'data' => expected_primary_data,
        'included' => [],
      })
    end
    it 'handles include of simple to-one relationship with compound document' do
      post = create(:post, :with_author)

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['author'],
      })
      expect(JSONAPI::Serializer.serialize(post, include: ['author'])).to eq({
        'data' => expected_primary_data,
        'included' => [
          serialize_primary(post.author, {serializer: MyAppOtherNamespace::UserSerializer}),
        ],
      })
    end
    it 'handles include of empty to-many relationships with compound document' do
      post = create(:post, :with_author, long_comments: [])

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['long-comments'],
      })
      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => expected_primary_data,
        'included' => [],
      })
    end
    it 'handles include of to-many relationships with compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['long-comments'],
      })
      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => expected_primary_data,
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

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['long-comments'],
      })
      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => expected_primary_data,
        'included' => [
          serialize_primary(long_comment, {serializer: MyApp::LongCommentSerializer}),
        ],
      })
    end
    it 'handles circular-referencing relationships with compound document' do
      long_comments = create_list(:long_comment, 2)
      post = create(:post, :with_author, long_comments: long_comments)

      # Make sure each long-comment has a circular reference back to the post.
      long_comments.each { |c| c.post = post }

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['long-comments'],
      })
      expect(JSONAPI::Serializer.serialize(post, include: ['long-comments'])).to eq({
        'data' => expected_primary_data,
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
        'data' => serialize_primary(post, {
          serializer: MyApp::PostSerializer,
          include_linkages: ['long-comments']
        }),
        'included' => [
          # Intermediates are included: long-comments, long-comments.post, and long-comments.post.author
          #  http://jsonapi.org/format/#document-structure-compound-documents
          serialize_primary(post.long_comments.first, {
            serializer: MyApp::LongCommentSerializer,
            include_linkages: ['post']
          }),
          serialize_primary(post.long_comments.last, {
            serializer: MyApp::LongCommentSerializer,
            include_linkages: ['post']
          }),
          serialize_primary(post, {
            serializer: MyApp::PostSerializer,
            include_linkages: ['author', 'post.long-comments', ]
          }),
          serialize_primary(post.author, {serializer: MyAppOtherNamespace::UserSerializer})
        ],
      }
      includes = ['long-comments.post.author']
      actual_data = JSONAPI::Serializer.serialize(post, include: includes)
      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end
    it 'handles recursive loading of multiple to-one relationships on children' do
      first_user = create(:user)
      second_user = create(:user)
      first_comment = create(:long_comment, user: first_user)
      second_comment = create(:long_comment, user: second_user)
      long_comments = [first_comment, second_comment]
      post = create(:post, :with_author, long_comments: long_comments)
      # Make sure each long-comment has a circular reference back to the post.
      long_comments.each { |c| c.post = post }

      expected_data = {
        'data' => serialize_primary(post, {
          serializer: MyApp::PostSerializer,
          include_linkages: ['long-comments']
        }),
        'included' => [
          serialize_primary(first_comment, {
            serializer: MyApp::LongCommentSerializer,
            include_linkages: ['user']
          }),
          serialize_primary(second_comment, {
            serializer: MyApp::LongCommentSerializer,
            include_linkages: ['user']
          }),
          serialize_primary(first_user, {serializer: MyAppOtherNamespace::UserSerializer}),
          serialize_primary(second_user, {serializer: MyAppOtherNamespace::UserSerializer}),
        ],
      }

      includes = ['long-comments.user']
      actual_data = JSONAPI::Serializer.serialize(post, include: includes)

      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end
    it 'includes linkage in compounded resources only if the immediate parent was also included' do
      comment_user = create(:user)
      long_comments = [create(:long_comment, user: comment_user)]
      post = create(:post, :with_author, long_comments: long_comments)

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['long-comments'],
      })
      expected_data = {
        'data' => expected_primary_data,
        'included' => [
          serialize_primary(long_comments.first, {
            serializer: MyApp::LongCommentSerializer,
            include_linkages: ['user'],
          }),
          # Note: post.author does not show up here because it was not included.
          serialize_primary(comment_user, {serializer: MyAppOtherNamespace::UserSerializer}),
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

      expected_primary_data = serialize_primary(post, {
        serializer: MyApp::PostSerializer,
        include_linkages: ['long-comments'],
      })
      expected_data = {
        'data' => expected_primary_data,
        'included' => [
          serialize_primary(long_comments.first, {
            serializer: MyApp::LongCommentSerializer,
            include_linkages: ['post'],
          }),
          serialize_primary(long_comments.last, {
            serializer: MyApp::LongCommentSerializer,
            include_linkages: ['post'],
          }),
          serialize_primary(post, {
            serializer: MyApp::PostSerializer,
            include_linkages: ['author'],
          }),
          serialize_primary(post.author, {serializer: MyAppOtherNamespace::UserSerializer}),
        ],
      }
      # Also test that it handles string include arguments.
      includes = 'long-comments,long-comments.post.author'
      actual_data = JSONAPI::Serializer.serialize(post, include: includes)

      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end

    context 'on collection' do
      it 'handles include of has_many relationships with compound document' do
        long_comments = create_list(:long_comment, 2)
        posts = create_list(:post, 2, :with_author, long_comments: long_comments)

        expected_primary_data = JSONAPI::Serializer.send(:serialize_primary_multi, posts, {
          serializer: MyApp::PostSerializer,
          include_linkages: ['long-comments'],
        })
        data = JSONAPI::Serializer.serialize(posts, is_collection: true, include: ['long-comments'])
        expect(data).to eq({
          'data' => expected_primary_data,
          'included' => [
            serialize_primary(long_comments.first, {serializer: MyApp::LongCommentSerializer}),
            serialize_primary(long_comments.last, {serializer: MyApp::LongCommentSerializer}),
          ],
        })
      end
    end

    context 'sparse fieldsets' do
      it 'allows to limit fields(attributes) for serialized resource' do
        first_user = create(:user)
        second_user = create(:user)
        first_comment = create(:long_comment, user: first_user)
        second_comment = create(:long_comment, user: second_user)
        long_comments = [first_comment, second_comment]
        post = create(:post, :with_author, long_comments: long_comments)

        serialized_data = JSONAPI::Serializer.serialize(post, fields: {posts: :title})
        expect(serialized_data).to eq ({
          'data' => {
            'type' => 'posts',
            'id' => post.id.to_s,
            'attributes' => {
              'title' => post.title,
            },
            'links' => {
              'self' => '/posts/1'
            }
          }
        })
      end
      it 'allows to limit fields(relationships) for serialized resource' do
        first_user = create(:user)
        second_user = create(:user)
        first_comment = create(:long_comment, user: first_user)
        second_comment = create(:long_comment, user: second_user)
        long_comments = [first_comment, second_comment]
        post = create(:post, :with_author, long_comments: long_comments)

        fields = {posts: 'title,author,long-comments'}
        serialized_data = JSONAPI::Serializer.serialize(post, fields: fields)
        expect(serialized_data['data']['relationships']).to eq ({
          'author' => {
            'links' => {
              'self' => '/posts/1/relationships/author',
              'related' => '/posts/1/author'
            }
          },
          'long-comments' => {
            'links' => {
              'self' => '/posts/1/relationships/long-comments',
              'related' => '/posts/1/long-comments'
            }
          }
        })
      end
      it "allows also to pass specific fields as array instead of comma-separates values" do
        first_user = create(:user)
        second_user = create(:user)
        first_comment = create(:long_comment, user: first_user)
        second_comment = create(:long_comment, user: second_user)
        long_comments = [first_comment, second_comment]
        post = create(:post, :with_author, long_comments: long_comments)

        serialized_data = JSONAPI::Serializer.serialize(post, fields: {posts: ['title', 'author']})
        expect(serialized_data['data']['attributes']).to eq ({
          'title' => post.title
        })
        expect(serialized_data['data']['relationships']).to eq ({
          'author' => {
            'links' => {
              'self' => '/posts/1/relationships/author',
              'related' => '/posts/1/author'
            }
          }
        })
      end
      it 'allows to limit fields(attributes and relationships) for included resources' do
        first_user = create(:user)
        second_user = create(:user)
        first_comment = create(:long_comment, user: first_user)
        second_comment = create(:long_comment, user: second_user)
        long_comments = [first_comment, second_comment]
        post = create(:post, :with_author, long_comments: long_comments)

        expected_primary_data = serialize_primary(post, {
          serializer: MyApp::PostSerializer,
          include_linkages: ['author'],
          fields: {'posts' => [:title, :author] }
        })

        fields = {posts: 'title,author', users: ''}
        serialized_data = JSONAPI::Serializer.serialize(post, fields: fields, include: 'author')
        expect(serialized_data).to eq ({
          'data' => expected_primary_data,
          'included' => [
            serialize_primary(
              post.author,
              serializer: MyAppOtherNamespace::UserSerializer,
              fields: {'users' => []},
            )
          ]
        })

        fields = {posts: 'title,author'}
        serialized_data = JSONAPI::Serializer.serialize(post, fields: fields, include: 'author')
        expect(serialized_data).to eq ({
          'data' => expected_primary_data,
          'included' => [
            serialize_primary(post.author, serializer: MyAppOtherNamespace::UserSerializer)
          ]
        })
      end
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
        'foo' => {_include: true, 'bar' => {_include: true}}
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
        'foo' => {_include: true, 'bar' => {_include: true, 'baz' => {_include: true}}}
      })
    end
  end
  describe 'if/unless handling with contexts' do
    it 'can be used to show/hide attributes' do
      post = create(:post)
      options = {serializer: MyApp::PostSerializerWithContext}

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
    it 'is passed through all relationship serializers' do
      # Force long_comments to be serialized by the context-sensitive serializer.
      expect_any_instance_of(MyApp::LongComment).to receive(:jsonapi_serializer_class_name)
        .at_least(:once)
        .and_return('MyApp::LongCommentsSerializerWithContext')

      user = create(:user, name: 'Long Comment Author -- Should Not Be Serialized')
      long_comment = create(:long_comment, user: user)
      post = create(:post, :with_author, long_comments: [long_comment])

      context = {show_body: false, show_comments_user: false}
      expected_data = {
        'data' => serialize_primary(post, {
          serializer: MyApp::PostSerializerWithContext,
          include_linkages: ['long-comments'],
          context: context,
        }),
        'included' => [
          serialize_primary(long_comment, {
            serializer: MyApp::LongCommentsSerializerWithContext,
            context: context,
          }),
        ],
      }
      includes = ['long-comments']
      actual_data = JSONAPI::Serializer.serialize(post, context: context, include: includes)
      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end
  end

  describe 'base_url' do
    it 'is empty by default' do
      long_comments = create_list(:long_comment, 1)
      post = create(:post, long_comments: long_comments)
      data = JSONAPI::Serializer.serialize(post)
      expect(data['data']['links']['self']).to eq('/posts/1')
      expect(data['data']['relationships']['author']['links']).to eq({
        'self' => '/posts/1/relationships/author',
        'related' => '/posts/1/author'
      })
    end
    it 'adds base_url to links if passed' do
      long_comments = create_list(:long_comment, 1)
      post = create(:post, long_comments: long_comments)
      data = JSONAPI::Serializer.serialize(post, base_url: 'http://example.com')
      expect(data['data']['links']['self']).to eq('http://example.com/posts/1')
      expect(data['data']['relationships']['author']['links']).to eq({
        'self' => 'http://example.com/posts/1/relationships/author',
        'related' => 'http://example.com/posts/1/author'
      })
    end
    it 'uses overriden base_url method if it exists' do
      long_comments = create_list(:long_comment, 1)
      post = create(:post, long_comments: long_comments)
      data = JSONAPI::Serializer.serialize(post, serializer: MyApp::PostSerializerWithBaseUrl)
      expect(data['data']['links']['self']).to eq('http://example.com/posts/1')
      expect(data['data']['relationships']['author']['links']).to eq({
        'self' => 'http://example.com/posts/1/relationships/author',
        'related' => 'http://example.com/posts/1/author'
      })
    end
  end

  describe 'inheritance through subclassing' do
    it 'inherits attributes' do
      tagged_post = create(:tagged_post)
      options = {serializer: MyApp::PostSerializerWithInheritedProperties}
      data = JSONAPI::Serializer.serialize(tagged_post, options);
      expect(data['data']['attributes']['title']).to eq('Title for TaggedPost 1');
      expect(data['data']['attributes']['tag']).to eq('Tag for TaggedPost 1');
    end

    it 'inherits relations' do
      long_comments = create_list(:long_comment, 2)
      tagged_post = create(:tagged_post, :with_author, long_comments: long_comments)
      options = {serializer: MyApp::PostSerializerWithInheritedProperties}
      data = JSONAPI::Serializer.serialize(tagged_post, options);

      expect(data['data']['relationships']).to eq({
        'author' => {
          'links' => {
            'self' => '/tagged-posts/1/relationships/author',
            'related' => '/tagged-posts/1/author',
          },
        },
        'long-comments' => {
          'links' => {
            'self' => '/tagged-posts/1/relationships/long-comments',
            'related' => '/tagged-posts/1/long-comments',
          }
        }
      })
    end
  end

  describe 'include validation' do
    it 'raises an exception when join character is invalid' do
      expect do
        JSONAPI::Serializer.serialize(create(:post), include: 'long_comments');
      end.to raise_error(JSONAPI::Serializer::InvalidIncludeError)

      expect do
        JSONAPI::Serializer.serialize(create(:post), include: 'long-comments');
      end.not_to raise_error

      expect do
        JSONAPI::Serializer.serialize(create(:underscore_test), include: 'tagged-posts');
      end.to raise_error(JSONAPI::Serializer::InvalidIncludeError)

      expect do
        JSONAPI::Serializer.serialize(create(:underscore_test), include: 'tagged_posts');
      end.not_to raise_error
    end
  end

  describe 'serializer with namespace option' do
    it 'can serialize a simple object with namespace Api::V1' do
      user = create(:user)
      expect(JSONAPI::Serializer.serialize(user, {namespace: Api::V1})).to eq({
        'data' => serialize_primary(user, {serializer: Api::V1::MyApp::UserSerializer}),
      })
    end

    it 'handles recursive loading of relationships with namespaces' do
      user = create(:user)
      long_comments = create_list(:long_comment, 2, user: user)
      post = create(:post, :with_author, long_comments: long_comments)
      # Make sure each long-comment has a circular reference back to the post.
      long_comments.each { |c| c.post = post }

      expected_data = {
        'data' => serialize_primary(post, {
          serializer: Api::V1::MyApp::PostSerializer,
          include_linkages: ['long-comments']
        }),
        'included' => [
          # Intermediates are included: long-comments, long-comments.post, and long-comments.post.author
          #  http://jsonapi.org/format/#document-structure-compound-documents
          serialize_primary(post.long_comments.first, {
            serializer: Api::V1::MyApp::LongCommentSerializer,
            include_linkages: ['post']
          }),
          serialize_primary(post.long_comments.last, {
            serializer: Api::V1::MyApp::LongCommentSerializer,
            include_linkages: ['post']
          }),
          serialize_primary(post, {
            serializer: Api::V1::MyApp::PostSerializer,
            include_linkages: ['author', 'post.long-comments']
          }),
          serialize_primary(post.author, {serializer: Api::V1::MyApp::UserSerializer})
        ],
      }
      includes = ['long-comments.post.author']
      actual_data = JSONAPI::Serializer.serialize(post, include: includes, namespace: Api::V1)
      # Multiple expectations for better diff output for debugging.
      expect(actual_data['data']).to eq(expected_data['data'])
      expect(actual_data['included']).to eq(expected_data['included'])
      expect(actual_data).to eq(expected_data)
    end
  end
end
