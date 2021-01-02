defmodule Snap.Bulk do
  @moduledoc """
  Supports streaming bulk operations against a `Snap.Cluster`.
  """

  @default_page_size 5000
  @default_page_wait 15_000

  alias Snap.Bulk.Actions

  @doc """
  Performs a bulk operation.

  Takes an `Enumerable` of action structs, where each struct is one of:

  * `Snap.Bulk.Action.Create`
  * `Snap.Bulk.Action.Index`
  * `Snap.Bulk.Action.Update`
  * `Snap.Bulk.Action.Delete`

  ```
  actions = [
    %Snap.Bulk.Action.Create{_id: 1, doc: %{foo: "bar"}},
    %Snap.Bulk.Action.Create{_id: 2, doc: %{foo: "bar"}},
    %Snap.Bulk.Action.Create{_id: 3, doc: %{foo: "bar"}}
  ]

  actions
  |> Snap.Bulk.perform(Cluster, "index")
  ```

  It chunks the `Enumerable` into pages, and pauses between pages for
  Elasticsearch to catch up. Uses `Stream` under the hood, so you can lazily
  feed it a stream of actions, such as out of an `Ecto.Repo` to bulk load
  documents from an SQL database.

  If no errors occur on any page it returns `:ok`. If any errors occur, on
  any page, it returns `{:error, [%Snap.Exception{}...]}`. It will continue
  to the end, even if errors occur.

  Options:

  * `page_size` - defines the size of each page, defaulting to 5000 actions.
  * `page_wait` - defines wait period between pages in ms, defaulting to
    15000ms.
  """
  @spec perform(Enumerable.t(), module(), String.t(), Keyword.t()) ::
          :ok | {:error, [Snap.Exception.t()]}
  def perform(stream, cluster, index, opts) do
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    page_wait = Keyword.get(opts, :page_wait, @default_page_wait)

    stream
    |> Stream.chunk_every(page_size)
    |> Stream.intersperse({:wait, page_wait})
    |> Stream.flat_map(&process_chunk(&1, cluster, index))
    |> Enum.to_list()
    |> handle_result()
  end

  defp process_chunk({:wait, 0}, _cluster, _index) do
    []
  end

  defp process_chunk({:wait, wait}, _cluster, _index) do
    :ok = :timer.sleep(wait)

    []
  end

  defp process_chunk(actions, cluster, index) do
    body = Actions.encode(actions)

    headers = [{"content-type", "application/x-ndjson"}]

    result = Snap.post(cluster, "/#{index}/_bulk", body, [], headers)

    case result do
      {:ok, %{"errors" => true, "items" => items}} ->
        process_errors(items)

      {:ok, _} ->
        []

      {:error, errors} ->
        errors
    end
  end

  defp handle_result([]), do: :ok
  defp handle_result(errors), do: {:error, errors}

  defp process_errors(items) do
    items
    |> Enum.map(&process_item/1)
    |> Enum.reject(&is_nil/1)
  end

  defp process_item(%{"create" => %{"error" => error} = item}) when is_map(error) do
    Snap.Exception.exception_from_response(item)
  end

  defp process_item(%{"index" => %{"error" => error} = item}) when is_map(error) do
    Snap.Exception.exception_from_response(item)
  end

  defp process_item(%{"update" => %{"error" => error} = item}) when is_map(error) do
    Snap.Exception.exception_from_response(item)
  end

  defp process_item(%{"delete" => %{"error" => error} = item}) when is_map(error) do
    Snap.Exception.exception_from_response(item)
  end

  defp process_item(_), do: nil
end
