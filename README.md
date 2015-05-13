# JSONAPI::Serializers

JSONAPI::Serializers is a simple library for serializing Ruby objects and their relationships into the [JSON:API format](http://jsonapi.org/format/).

Note: as of writing, the JSON:API spec has not reached v1 and is still undergoing changes. This library supports RC3+ and aims to keep up with the continuing development changes.

## Features

* Works with **any Ruby web framework**, including Rails, Sinatra, etc. This is a pure Ruby library.
* Supports the readonly features of the JSON:API spec.
  * **Full support for compound documents** ("side-loaded" objects) and the `include` parameter.
* Similar interface to ActiveModel::Serializers, should provide an easy migration path.
* Intentionally unopinionated, allows you to structure your app however you would like and then serialize the objects at the end.

JSONAPI::Serializers was built as an intentionally simple serialization interface. It makes no assumptions about your database structure or routes and it does not provide controllers or any create/update interface to your objects. It is a library, not a framework. You will probably still need to do work to make your API fully compliant with the nuances of the [JSON:API spec](http://jsonapi.org/format/), for things like supporting `/links` routes and of course for implementing any mutation action like PATCH or creating objects. If you are looking for a more complete and opinionated framework, see the [jsonapi-resources](https://github.com/cerebris/jsonapi-resources) project.

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
  attribute :content
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
      "content": "Your first post"
    },
    "links": {
      "self": "/posts/1"
    }
  }
}
```

### Serialize a collection

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
        "content": "Your first post"
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
        "content": "Your second post"
      },
      "links": {
        "self": "/posts/2"
      }
    }
  ]
}
```

### Null handling

Note that the JSON:API spec distinguishes in how null/empty is handled for single objects vs. collections, so you must always provide `is_collection: true` when serializing multiple objects. If you attempt to serialize multiple objects without this flag (or a single object with it on) a `JSONAPI::Serializer::AmbiguousCollectionError` will be raised.

```ruby
JSONAPI::Serializer.serialize(nil)
```

Returns:
```json
{
  "data": null
}
```

And serializing an empty collection:
```ruby
JSONAPI::Serializer.serialize([], is_collection: true)
```

Returns:
```json
{
  "data": []
}
```


```ruby
JSONAPI::Serializer.serialize([], is_collection: true)
```


### Custom attributes

By default the serializer looks for the same name of the attribute on the object it is given. You can customize this behavior by providing a block to the attribute:

```ruby
  attribute :content do
    object.body
  end
```

The block is evaluated within the serializer instance, so it has access to the `object` and `context` instance variables.

### Relationships

You can easily specify relationships with the `has_one` and `has_many` directives.

```ruby
class BaseSerializer
  include JSONAPI::Serializer
end

class PostSerializer < BaseSerializer
  attribute :title
  attribute :content

  has_one :author
  has_many :comments
end

class UserSerializer < BaseSerializer
  attribute :name
end

class CommentSerializer < BaseSerializer
  attribute :content

  has_one :user
end
```

Note that when serializing a post, the `author` association will come from the `author` attribute on the `Post` instance, no matter what type it is (in this case it is a `User`). This will work just fine, because JSONAPI::Serializers automatically finds serializer classes by appending `Serializer` to the object's class name (this can be customized).

Because the full class name is used when discovering serializers, JSONAPI::Serializers works with any custom namespaces you might have, like a Rails Engine or standard Ruby module namespace.

### Serialize compound documents

> To reduce the number of HTTP requests, servers MAY allow responses that include related resources along with the requested primary resources. Such responses are called "compound documents". [JSON:API Compound Documents](http://jsonapi.org/format/#document-structure-compound-documents)

JSONAPI::Serializers supports compound documents with a simple `include` parameter.

For example:

```ruby
JSONAPI::Serializer.serialize(post, include: ['author', 'comments', 'comments.user'])
```

Returns:

```json

  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Hello World",
      "content": "Your first post"
    },
    "links": {
      "self": "/posts/1",
      "author": {
        "self": "/posts/1/links/author",
        "related": "/posts/1/author",
        "linkage": {
          "type": "users",
          "id": "1"
        }
      },
      "comments": {
        "self": "/posts/1/links/comments",
        "related": "/posts/1/comments",
        "linkage": [
          {
            "type": "comments",
            "id": "1"
          }
        ]
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "Post Author"
      },
      "links": {
        "self": "/users/1"
      }
    },
    {
      "id": "1",
      "type": "comments",
      "attributes": {
        "content": "Have no fear, sers, your king is safe."
      },
      "links": {
        "self": "/comments/1",
        "user": {
          "self": "/comments/1/links/user",
          "related": "/comments/1/user",
          "linkage": {
            "type": "users",
            "id": "2"
          }
        }
      }
    },
    {
      "id": "2",
      "type": "users",
      "attributes": {
        "name": "Barristan Selmy"
      },
      "links": {
        "self": "/users/2"
      }
    }
  ]
}
```

The `include` param also accepts a string of [relationship paths](http://jsonapi.org/format/#fetching-includes), ie. `include: 'author,comments,comments.user'` so you can pass an `?include` query param directly in. Be aware that letting users pass arbitrary relationship paths might introduce security issues depending on your authorization setup, where a user could `include` a relationship they might not be authorized to see directly. Be aware of what you allow API users to include.

## Contributing

1. Fork it ( https://github.com/fotinakis/jsonapi-serializers/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
