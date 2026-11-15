defmodule Mudbrick.Catalog do
  @moduledoc false

  @enforce_keys [:metadata, :page_tree]
  defstruct [:metadata, :page_tree, attachments: [], output_intent: nil]

  @doc false
  def new(opts) do
    struct!(__MODULE__, opts)
  end

  defimpl Mudbrick.Object do
    def to_iodata(catalog) do
      %{
        Type: :Catalog,
        Metadata: catalog.metadata.ref,
        Pages: catalog.page_tree.ref
      }
      |> put_attachments(catalog.attachments)
      |> put_output_intent(catalog.output_intent)
      |> Mudbrick.Object.to_iodata()
    end

    defp put_attachments(dict, []), do: dict

    defp put_attachments(dict, attachments) do
      # The name tree's keys must be sorted; /AF carries the PDF/A-3 association.
      names =
        attachments
        |> Enum.sort_by(fn {name, _} -> name end)
        |> Enum.flat_map(fn {name, filespec} -> [name, filespec.ref] end)

      Map.merge(dict, %{
        AF: Enum.map(attachments, fn {_, filespec} -> filespec.ref end),
        Names: %{EmbeddedFiles: %{Names: names}}
      })
    end

    defp put_output_intent(dict, nil), do: dict
    defp put_output_intent(dict, intent), do: Map.put(dict, :OutputIntents, [intent.ref])
  end
end
