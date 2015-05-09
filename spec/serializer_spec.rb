describe JSONAPI::Serializer do
  describe 'serialize_primary_data' do
    it 'can serialize a simple object' do
      post = create(:post)
      expect(MyApp::PostSerializer.serialize_primary_data(post)).to eq({
        'id' => 1,
        'type' => 'posts',
        'attributes' => {
          'title' => 'Title for Post 1',
        },
        'links' => {
          'self' => "/posts/1",
        },
      })
    end
  end
end