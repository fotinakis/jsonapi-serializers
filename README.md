# JSONAPI::Serializers

[![Build Status](https://travis-ci.org/fotinakis/jsonapi-serializers.svg?branch=master)](https://travis-ci.org/fotinakis/jsonapi-serializers)
[![Gem Version](https://badge.fury.io/rb/jsonapi-serializers.svg)](http://badge.fury.io/rb/jsonapi-serializers)

JSONAPI::Serializers is a simple library for serializing Ruby objects and their relationships into the [JSON:API format](http://jsonapi.org/format/).

This library is up-to-date with the finalized v1 JSON API spec.

* [Features](#features)
* [Installation](#installation)
* [Usage](#usage)
  * [Define a serializer](#define-a-serializer)
  * [Serialize an object](#serialize-an-object)
  * [Serialize a collection](#serialize-a-collection)
  * [Null handling](#null-handling)
  * [Multiple attributes](#multiple-attributes)
  * [Custom attributes](#custom-attributes)
  * [More customizations](#more-customizations)
  * [Base URL](#base-url)
  * [Root metadata](#root-metadata)
  * [Root links](#root-links)
  * [Root errors](#root-errors)
  * [Root jsonapi object](#root-jsonapi-object)
  * [Explicit serializer discovery](#explicit-serializer-discovery)
  * [Namespace serializers](#namespace-serializers)
  * [Sparse fieldsets](#sparse-fieldsets)
* [Relationships](#relationships)
  * [Compound documents and includes](#compound-documents-and-includes)
  * [Relationship path handling](#relationship-path-handling)
  * [Control links and data in relationships](#control-links-and-data-in-relationships)
* [Rails example](#rails-example)
* [Sinatra example](#sinatra-example)
* [Unfinished business](#unfinished-business)
* [Contributing](#contributing)

## Features

* Works with **any Ruby web framework**, including Rails, Sinatra, etc. This is a pure Ruby library.
* Supports the readonly features of the JSON:API spec.
  * **Full support for compound documents** ("side-loading") and the `include` parameter.
* Similar interface to ActiveModel::Serializers, should provide an easy migration path.
* Intentionally unopinionated and simple, allows you to structure your app however you would like and then serialize the objects at the end. Easy to integrate with your existing authorization systems and service objects.

JSONAPI::Serializers was built as an intentionally simple serialization interface. It makes no assumptions about your database structure or routes and it does not provide controllers or any create/update interface to the objects. It is a library, not a framework. You will probably still need to do work to make your API fully compliant with the nuances of the [JSON:API spec](http://jsonapi.org/format/), for things like supporting `/relationships` routes and for supporting write actions like creating or updating objects. If you are looking for a more complete and opinionated framework, see the [jsonapi-resources](https://github.com/cerebris/jsonapi-resources) project.

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

You must always pass `is_collection: true` when serializing a collection, see [Null handling](#null-handling).

### Null handling

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

Note that the JSON:API spec distinguishes in how null/empty is handled for single objects vs. collections, so you must always provide `is_collection: true` when serializing multiple objects. If you attempt to serialize multiple objects without this flag (or a single object with it on) a `JSONAPI::Serializer::AmbiguousCollectionError` will be raised.

### Multiple attributes
You could declare multiple attributes at once:

```ruby
 attributes :title, :body, :contents
```

### Custom attributes

By default the serializer looks for the same name of the attribute on the object it is given. You can customize this behavior by providing a block to `attribute`, `has_one`, or `has_many`:

```ruby
  attribute :content do
    object.body
  end

  has_one :comment do
    Comment.where(post: object).take!
  end

  has_many :authors do
    Author.where(post: object)
  end
```

The block is evaluated within the serializer instance, so it has access to the `object` and `context` instance variables.

### More customizations

Many other formatting and customizations are possible by overriding any of the following instance methods on your serializers.

```ruby
# Override this to customize the JSON:API "id" for this object.
# Always return a string from this method to conform with the JSON:API spec.
def id
  object.slug.to_s
end
```
```ruby
# Override this to customize the JSON:API "type" for this object.
# By default, the type is the object's class name lowercased, pluralized, and dasherized,
# per the spec naming recommendations: http://jsonapi.org/recommendations/#naming
# For example, 'MyApp::LongCommment' will become the 'long-comments' type.
def type
  'long-comments'
end
```
```ruby
# Override this to customize how attribute names are formatted.
# By default, attribute names are dasherized per the spec naming recommendations:
# http://jsonapi.org/recommendations/#naming
def format_name(attribute_name)
  attribute_name.to_s.dasherize
end
```
```ruby
# The opposite of format_name. Override this if you override format_name.
def unformat_name(attribute_name)
  attribute_name.to_s.underscore
end
```
```ruby
# Override this to provide resource-object metadata.
# http://jsonapi.org/format/#document-structure-resource-objects
def meta
end
```
```ruby
# Override this to set a base URL (http://example.com) for all links. No trailing slash.
def base_url
  @base_url
end
```
```ruby
# Override this to provide a resource-object jsonapi object containing the version in use.
# http://jsonapi.org/format/#document-jsonapi-object
def jsonapi
end
```
```ruby
def self_link
  "#{base_url}/#{type}/#{id}"
end
```
```ruby
def relationship_self_link(attribute_name)
  "#{self_link}/relationships/#{format_name(attribute_name)}"
end
```
```ruby
def relationship_related_link(attribute_name)
  "#{self_link}/#{format_name(attribute_name)}"
end
```

If you override `self_link`, `relationship_self_link`, or `relationship_related_link` to return `nil`, the link will be excluded from the serialized object.

### Base URL

You can override the `base_url` instance method to set a URL to be used in all links.

```ruby
class BaseSerializer
  include JSONAPI::Serializer

  def base_url
    'http://example.com'
  end
end

class PostSerializer < BaseSerializer
  attribute :title
  attribute :content

  has_one :author
  has_many :comments
end

JSONAPI::Serializer.serialize(post)
```

Returns:

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
      "self": "http://example.com/posts/1"
    },
    "relationships": {
      "author": {
        "links": {
          "self": "http://example.com/posts/1/relationships/author",
          "related": "http://example.com/posts/1/author"
        }
      },
      "comments": {
        "links": {
          "self": "http://example.com/posts/1/relationships/comments",
          "related": "http://example.com/posts/1/comments"
        },
      }
    }
  }
}
```

Alternatively, you can specify `base_url` as an argument to `serialize` which allows you to build the URL with different subdomains or other logic from the request:

```ruby
JSONAPI::Serializer.serialize(post, base_url: 'http://example.com')
```

Note: if you override `self_link` in your serializer and leave out `base_url`, it will not be included.

### Root metadata

You can pass a `meta` argument to specify top-level metadata:

```ruby
JSONAPI::Serializer.serialize(post, meta: {copyright: 'Copyright 2015 Example Corp.'})
```

### Root links

You can pass a `links` argument to specify top-level links:

```ruby
JSONAPI::Serializer.serialize(post, links: {self: 'https://example.com/posts'})
```

### Root errors

You can use `serialize_errors` method in order to specify top-level errors:

```ruby
errors = [{ "title": "Invalid Attribute", "detail": "First name must contain at least three characters." }]
JSONAPI::Serializer.serialize_errors(errors)
```

If you are using Rails models (ActiveModel by default), you can pass in an object's errors:

```ruby
JSONAPI::Serializer.serialize_errors(user.errors)
```

A more complete usage example (assumes ActiveModel):

```ruby
class Api::V1::ReposController < Api::V1::BaseController
  def create
    post = Post.create(post_params)
    if post.errors
      render json: JSONAPI::Serializer.serialize_errors(post.errors)
    else
      render json: JSONAPI::Serializer.serialize(post)
    end
  end
end
```

### Root 'jsonapi' object

You can pass a `jsonapi` argument to specify a [top-level "jsonapi" key](http://jsonapi.org/format/#document-jsonapi-object) containing the version of JSON:API in use:

```ruby
JSONAPI::Serializer.serialize(post, jsonapi: {version: '1.0'})
```

### Explicit serializer discovery

By default, jsonapi-serializers assumes that the serializer class for `Namespace::User` is `Namespace::UserSerializer`. You can override this behavior on a per-object basis by implementing the `jsonapi_serializer_class_name` method.

```ruby
class User
  def jsonapi_serializer_class_name
    'SomeOtherNamespace::CustomUserSerializer'
  end
end
```

Now, when a `User` object is serialized, it will use the `SomeOtherNamespace::CustomUserSerializer`.

### Namespace serializers

Assume you have an API with multiple versions:

```ruby
module Api
  module V1
    class PostSerializer
      include JSONAPI::Serializer
      attribute :title
    end
  end
  module V2
    class PostSerializer
      include JSONAPI::Serializer
      attribute :name
    end
  end
end
```

With the namespace option you can choose which serializer is used.

```ruby
JSONAPI::Serializer.serialize(post, namespace: Api::V1)
JSONAPI::Serializer.serialize(post, namespace: Api::V2)
```

This option overrides the `jsonapi_serializer_class_name` method.

### Sparse fieldsets

The JSON:API spec allows to return only [specific fields](http://jsonapi.org/format/#fetching-sparse-fieldsets) from attributes and relationships.

For example, if you wanted to return only the `title` field and `author` relationship link for `posts`:

```ruby
fields =
JSONAPI::Serializer.serialize(post, fields: {posts: [:title]})
```

Sparse fieldsets also affect relationship links. In this case, only the `author` relationship link would be included:

``` ruby
JSONAPI::Serializer.serialize(post, fields: {posts: [:title, :author]})
```

Sparse fieldsets operate on a per-type basis, so they affect all resources in the response including in compound documents. For example, this will affect both the `posts` type in the primary data and the `users` type in the compound data:

``` ruby
JSONAPI::Serializer.serialize(
  post,
  fields: {posts: ['title', 'author'], users: ['name']},
  include: 'author',
)
```

Sparse fieldsets support comma-separated strings (`fields: {posts: 'title,author'}`, arrays of strings (`fields: {posts: ['title', 'author']}`), single symbols (`fields: {posts: :title}`), and arrays of symbols (`fields: {posts: [:title, :author]}`).

## Relationships

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

Note that when serializing a post, the `author` association will come from the `author` attribute on the `Post` instance, no matter what type it is (in this case it is a `User`). This will work just fine, because JSONAPI::Serializers automatically finds serializer classes by appending `Serializer` to the object's class name. This behavior can be customized.

Because the full class name is used when discovering serializers, JSONAPI::Serializers works with any custom namespaces you might have, like a Rails Engine or standard Ruby module namespace.

### Compound documents and includes

> To reduce the number of HTTP requests, servers MAY allow responses that include related resources along with the requested primary resources. Such responses are called "compound documents".
> [JSON:API Compound Documents](http://jsonapi.org/format/#document-structure-compound-documents)

JSONAPI::Serializers supports compound documents with a simple `include` parameter.

For example:

```ruby
JSONAPI::Serializer.serialize(post, include: ['author', 'comments', 'comments.user'])
```

Returns:

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
    },
    "relationships": {
      "author": {
        "links": {
          "self": "/posts/1/relationships/author",
          "related": "/posts/1/author"
        },
        "data": {
          "type": "users",
          "id": "1"
        }
      },
      "comments": {
        "links": {
          "self": "/posts/1/relationships/comments",
          "related": "/posts/1/comments"
        },
        "data": [
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
        "self": "/comments/1"
      },
      "relationships": {
        "user": {
          "links": {
            "self": "/comments/1/relationships/user",
            "related": "/comments/1/user"
          },
          "data": {
            "type": "users",
            "id": "2"
          }
        },
        "post": {
          "links": {
            "self": "/comments/1/relationships/post",
            "related": "/comments/1/post"
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

Notice a few things:
* The [primary data](http://jsonapi.org/format/#document-structure-top-level) relationships now include "linkage" information for each relationship that was included.
* The related objects themselves are loaded in the top-level `included` member.
* The related objects _also_ include "linkage" data when a deeper relationship is also present in the compound document. This is a very powerful feature of the JSON:API spec, and allows you to deeply link complicated relationships all in the same document and in a single HTTP response. JSONAPI::Serializers automatically includes the correct linkage data for whatever `include` paths you specify. This conforms to this part of the spec:

  > Note: Full linkage ensures that included resources are related to either the primary data (which could be resource objects or resource identifier objects) or to each other.
  > [JSON:API Compound Documents](http://jsonapi.org/format/#document-compound-documents)

#### Relationship path handling

The `include` param also accepts a string of [relationship paths](http://jsonapi.org/format/#fetching-includes), ie. `include: 'author,comments,comments.user'` so you can pass an `?include` query param directly through to the serialize method. Be aware that letting users pass arbitrary relationship paths might introduce security issues depending on your authorization setup, where a user could `include` a relationship they might not be authorized to see directly. Be aware of what you allow API users to include.

### Control `links` and `data` in relationships

The JSON API spec allows relationships objects to contain `links`, `data`, or both.

By default, `links` are included in each relationship. You can remove links for a specific relationship by passing `include_links: false` to `has_one` or `has_many`. For example:

```ruby
has_many :comments, include_links: false  # Default is include_links: true.
```

Notice that `links` are now excluded for the `comments` relationship:

```json
   "relationships": {
     "author": {
       "links": {
         "self": "/posts/1/relationships/author",
         "related": "/posts/1/author"
       }
     },
     "comments": {}
   }
```

By default, `data` is excluded in each relationship. You can enable data for a specific relationship by passing `include_data: true` to `has_one` or `has_many`. For example:

```ruby
has_one :author, include_data: true  # Default is include_data: false.
```

Notice that linkage data is now included for the `author` relationship:

```json
   "relationships": {
     "author": {
       "links": {
         "self": "/posts/1/relationships/author",
         "related": "/posts/1/author"
       },
       "data": {
         "type": "users",
         "id": "1"
       }
     }
```

## Rails example

```ruby
# app/serializers/base_serializer.rb
class BaseSerializer
  include JSONAPI::Serializer

  def self_link
    "/api/v1#{super}"
  end
end

# app/serializers/post_serializer.rb
class PostSerializer < BaseSerializer
  attribute :title
  attribute :content
end

# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ActionController::Base
  # Convenience methods for serializing models:
  def serialize_model(model, options = {})
    options[:is_collection] = false
    JSONAPI::Serializer.serialize(model, options)
  end

  def serialize_models(models, options = {})
    options[:is_collection] = true
    JSONAPI::Serializer.serialize(models, options)
  end
end

# app/controllers/api/v1/posts_controller.rb
class Api::V1::ReposController < Api::V1::BaseController
  def index
    posts = Post.all
    render json: serialize_models(posts)
  end

  def show
    post = Post.find(params[:id])
    render json: serialize_model(post)
  end
end

# config/initializers/jsonapi_mimetypes.rb
# Without this mimetype registration, controllers will not automatically parse JSON API params.
module JSONAPI
  MIMETYPE = "application/vnd.api+json"
end
Mime::Type.register(JSONAPI::MIMETYPE, :api_json)

# Rails 4
ActionDispatch::ParamsParser::DEFAULT_PARSERS[Mime::Type.lookup(JSONAPI::MIMETYPE)] = lambda do |body|
  JSON.parse(body)
end

# Rails 5 moved DEFAULT_PARSERS
ActionDispatch::Http::Parameters::DEFAULT_PARSERS[:api_json] = lambda do |body|
  JSON.parse(body)
end
ActionDispatch::Request.parameter_parsers = ActionDispatch::Request::DEFAULT_PARSERS

```

## Sinatra example

Here's an example using [Sinatra](http://www.sinatrarb.com) and
[Sequel ORM](http://sequel.jeremyevans.net) instead of Rails and ActiveRecord.
The important takeaways here are that:

1. The `:tactical_eager_loading` plugin will greatly reduce the number of
   queries performed when sideloading associated records. You can add this
   plugin to a single model (as demonstrated here), or globally to all models.
   For more information, please see the Sequel
   [documentation](http://sequel.jeremyevans.net/rdoc-plugins/classes/Sequel/Plugins/TacticalEagerLoading.html).
1. The `:skip_collection_check` option must be set to true in order for
   JSONAPI::Serializer to be able to serialize a single Sequel::Model instance.
1. You should call `#all` on your Sequel::Dataset instances before passing them
   to JSONAPI::Serializer to greatly reduce the number of queries performed.

```ruby
require 'sequel'
require 'sinatra/base'
require 'json'
require 'jsonapi-serializers'

class Post < Sequel::Model
  plugin :tactical_eager_loading

  one_to_many :comments
end

class Comment < Sequel::Model
  many_to_one :post
end

class BaseSerializer
  include JSONAPI::Serializer

  def self_link
    "/api/v1#{super}"
  end
end

class PostSerializer < BaseSerializer
  attributes :title, :content

  has_many :comments
end

class CommentSerializer < BaseSerializer
  attributes :username, :content

  has_one :post
end

module Api
  class V1 < Sinatra::Base
    configure do
      mime_type :api_json, 'application/vnd.api+json'

      set :database, Sequel.connect
    end

    helpers do
      def parse_request_body
        return unless request.body.respond_to?(:size) &&
          request.body.size > 0

        halt 415 unless request.content_type &&
          request.content_type[/^[^;]+/] == mime_type(:api_json)

        request.body.rewind
        JSON.parse(request.body.read, symbolize_names: true)
      end

      # Convenience methods for serializing models:
      def serialize_model(model, options = {})
        options[:is_collection] = false
        options[:skip_collection_check] = true
        JSONAPI::Serializer.serialize(model, options)
      end

      def serialize_models(models, options = {})
        options[:is_collection] = true
        JSONAPI::Serializer.serialize(models, options)
      end
    end

    before do
      halt 406 unless request.preferred_type.entry == mime_type(:api_json)
      @data = parse_request_body
      content_type :api_json
    end

    get '/posts' do
      posts = Post.all
      serialize_models(posts).to_json
    end

    get '/posts/:id' do
      post = Post[params[:id].to_i]
      not_found if post.nil?
      serialize_model(post, include: 'comments').to_json
    end
  end
end
```

See also: [Sinja](https://github.com/mwpastore/sinja), which extends Sinatra
and leverages jsonapi-serializers to provide a JSON:API framework.

## Changelog

See [Releases](https://github.com/fotinakis/jsonapi-serializers/releases).

## Unfinished business

* Support for pagination/sorting is unlikely to be supported because it would likely involve coupling to ActiveRecord, but please open an issue if you have ideas of how to support this generically.

## Contributing

1. Fork it ( https://github.com/fotinakis/jsonapi-serializers/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

Throw a ★ on it! :)
