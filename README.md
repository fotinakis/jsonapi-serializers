# JSONAPI::Serializers

JSONAPI::Serializers is a simple library for serializing Ruby objects and their relationships into the [JSON:API format](http://jsonapi.org/format/).

Note: as of writing, the JSON:API spec has not reached v1 and is still undergoing changes. This library supports RC3+ and aims to keep up with the continuing development changes.

## Features

* Works with **any Ruby web framework**, including Rails, Sinatra, etc. This is a pure Ruby library.
* Supports the readonly features of the JSON:API spec.
  * **Full support for compound documents** ("side-loaded" objects) and the `include` parameter.
* Similar interface to ActiveModel::Serializers, should provide an easy migration path.
* Intentionally unopinionated, allows you to structure your app however you would like and then serialize the objects at the end.

JSONAPI::Serializers was built as an intentionally simple serialization interface. It makes no assumptions about your database structure or routes and it does not provide controllers or any create/update interface to your objects. It is a library, not a framework. You will probably still need to do work to make your API fully compliant with the nuances of the [JSON:API spec](http://jsonapi.org/format/), for things like supporting `/links` routes and of course for implementing any mutation action like PATCH or creating objects. If you are looking for a more complete and opiniated framework, see the [jsonapi-resources](https://github.com/cerebris/jsonapi-resources) project.

Note: still under development, doesn't currently support certain readonly things like `fields`, but I'd like to.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jsonapi-serializers'
```

Or install directly with `gem install jsonapi-serializers`.

## Usage

### Define a serializer

```ruby
require 'jsonapi-serializers'

class PostSerializer
  include JSONAPI::Serializer
  
  attribute :title
  attribute :body
end
```

### Serialize an object

```ruby
JSONAPI::Serializer.serialize(post)
```

Returns a hash:
```json
{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Hello World",
      "body": "Your first post"
    },
    "links": {
      "self": "/posts/1"
    }
  }
}
```

### Serialize multiple objects

```ruby
JSONAPI::Serializer.serialize(posts, is_collection: true)
```

Returns:

```json
{
  "data": [
    {
      "id": "1",
      "type": "posts",
      "attributes": {
        "title": "Hello World",
        "body": "Your first post"
      },
      "links": {
        "self": "/posts/1"
      }
    },
    {
      "id": "2",
      "type": "posts",
      "attributes": {
        "title": "Hello World again",
        "body": "Your second post"
      },
      "links": {
        "self": "/posts/2"
      }
    }
  ]
}
```

> Note: the JSON:API spec makes a specific distinction in how null `linkage` information is presented for single objects vs. collections, so you must always provide `is_collection: true` when serializing multiple objects. If you attempt to serialize multiple objects without this flag (or a single object with it) a `JSONAPI::Serializer::AmbiguousCollectionError` will be raised.

### Serialize compound documents

> To reduce the number of HTTP requests, servers MAY allow responses that include related resources along with the requested primary resources. Such responses are called "compound documents". [JSON:API Compound Documents](http://jsonapi.org/format/#document-structure-compound-documents)

...

## Contributing

1. Fork it ( https://github.com/fotinakis/jsonapi-serializers/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
