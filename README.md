# Snap

[![Hex pm](http://img.shields.io/hexpm/v/snap.svg?style=flat)](https://hex.pm/packages/snap)

Snap is an Elasticsearch/OpenSearch client. It provides a flexible, performant API on
top of your Elasticsearch cluster, supporting high level features like
versioned index management, while also providing a convenient interface into
low level operations.

See the full [API docs](https://hexdocs.pm/snap).

## Features

- Versioned index management with zero-downtime hotswapping (compatible with [`elasticsearch`](https://github.com/danielberkompas/elasticsearch-elixir))
- Streaming bulk operations
- Connection pooling
- Telemetry events
- High level interface over the [Multi Search API](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-multi-search.html)

## Installation

The package can be installed by adding `snap` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:snap, "~> 0.17"},
    {:finch, "~> 0.21"}, # By default, Snap uses Finch to make HTTP requests
  ]
end
```

Snap supports Elixir 1.16 or later.

## Usage

Implement your own cluster module, similar to an `Ecto.Repo`:

```elixir
defmodule MyApp.Cluster do
  use Snap.Cluster, otp_app: :my_app
end
```

Configure it:

```elixir
config :my_app, MyApp.Cluster,
  url: "http://localhost:9200",
  username: "my_username",
  password: "my_password"
```

Then wire it into your application supervisor:

```elixir
def start(_type, _args) do
  children = [
    {MyApp.Cluster, []}
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Now you can perform operations on your cluster:

```elixir
{:ok, %{"count" => count}} = MyApp.Cluster.get("/my-index/_count")
```

## Livebook

To use in [livebook](https://livebook.dev) you can try this;

```elixir
Mix.install([
  {:snap, "~> 0.9.0"},
  {:kino, "~> 0.12.3"},
  {:finch, "~> 0.18.0"}
])

defmodule Elastic do
  use Snap.Cluster, otp_app: :snap
end

Kino.start_child!({Elastic, [url: "http://elastic.local:9200"]})

Snap.Search.search(Elastic, "products", %{query: %{match_all: %{}}})
```

## Testing

See `Snap.Test` for details about to set up process isolated indexes to allow
async testing against Snap.

If you want to test your app that uses this library, but don't want to have integration tests
with a Elasticsearch instance running in you local dev environment,
you can mock the responses using a custom HTTP client adapter.

Supposing you are using [mox](https://github.com/dashbitco/mox), you can do something like this:

```elixir
# in test_helper.exs
Mox.defmock(HTTPClientMock, for: Snap.HTTPClient)
Mox.stub(HTTPClientMock, :child_spec, fn _config -> :skip end)

# in config/test.exs
config :my_app, MyApp.Cluster, http_client_adapter: HTTPClientMock

# in a test file
Mox.expect(HTTPClientMock, :request, fn _cluster, _method, _url, _headers, _body, _opts
  body = "{}" # valid json
  {:ok, %Snap.HTTPClient.Response{status: 200, headers: [], body: body}}
end)
```

See the [API documentation](https://hexdocs.pm/snap) for more advanced features.
