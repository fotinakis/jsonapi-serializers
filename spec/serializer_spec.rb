describe JSONAPI::Serializer do
  describe 'serialize_primary_data' do
    it 'can serialize a simple object' do
      post = create(:post)
      expect(MyApp::SimplePostSerializer.serialize_primary_data(post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => "/posts/1",
        },
      })
    end
    it 'can serialize a null to-one relationship' do
      post = create(:post, author: nil)
      expect(MyApp::PostSerializer.serialize_primary_data(post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => "/posts/1",
          'author' => {
            'self' => "/posts/1/links/author",
            'related' => "/posts/1/author",
            # Spec: Resource linkage MUST be represented as one of the following:
            # - null for empty to-one relationships.
            # http://jsonapi.org/format/#document-structure-resource-relationships
            'linkage' => nil,
          },
        },
      })
    end
    it 'can serialize a simple to-one relationship' do
      post = create(:post, :with_author)
      expect(MyApp::PostSerializer.serialize_primary_data(post)).to eq({
        'id' => '1',
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
          'long-content' => 'Body for Post 1',
        },
        'links' => {
          'self' => "/posts/1",
          'author' => {
            'self' => "/posts/1/links/author",
            'related' => "/posts/1/author",
            'linkage' => {
              'type' => 'users',
              'id' => '1',
            },
          },
        },
      })
    end
  end
end