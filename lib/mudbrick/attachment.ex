defmodule Mudbrick.Attachment do
  @moduledoc """
  An embedded file associated with the whole document (PDF/A-3 "associated file").

  Registered through `Mudbrick.new(attachments: [...])`; each one becomes an
  `/EmbeddedFile` stream, a `/Filespec` listed in the catalog's `/AF` array and
  in the `/EmbeddedFiles` name tree.
  """

  @enforce_keys [:filename, :data, :mime_type]
  defstruct [
    :filename,
    :data,
    :mime_type,
    :modified,
    description: nil,
    relationship: :Data
  ]

  @type relationship :: :Source | :Data | :Alternative | :Supplement | :Unspecified

  @type t :: %__MODULE__{
          filename: String.t(),
          data: binary(),
          mime_type: String.t(),
          modified: DateTime.t() | nil,
          description: String.t() | nil,
          relationship: relationship()
        }

  alias Mudbrick.Document
  alias Mudbrick.Stream

  @doc "Builds an attachment from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(opts), do: struct!(__MODULE__, opts)

  @doc false
  def add_objects(doc, attachments) do
    Enum.reduce(attachments, {doc, []}, fn attachment, {doc, filespecs} ->
      attachment = if is_struct(attachment, __MODULE__), do: attachment, else: new(attachment)
      {doc, file} = Document.add(doc, embedded_file(attachment, doc.compress))
      {doc, filespec} = Document.add(doc, filespec(attachment, file))
      {doc, filespecs ++ [{attachment.filename, filespec}]}
    end)
  end

  defp embedded_file(attachment, compress) do
    params =
      %{Size: byte_size(attachment.data)}
      |> maybe_put(:ModDate, attachment.modified && pdf_date(attachment.modified))

    Stream.new(
      compress: compress,
      data: attachment.data,
      additional_entries: %{
        Type: :EmbeddedFile,
        Subtype: String.to_atom(attachment.mime_type),
        Params: params
      }
    )
  end

  defp filespec(attachment, file) do
    %{
      Type: :Filespec,
      F: attachment.filename,
      UF: attachment.filename,
      EF: %{F: file.ref, UF: file.ref},
      AFRelationship: attachment.relationship
    }
    |> maybe_put(:Desc, attachment.description)
  end

  @doc false
  def pdf_date(%DateTime{} = dt) do
    dt = DateTime.shift_zone!(dt, "Etc/UTC")
    "D:" <> Calendar.strftime(dt, "%Y%m%d%H%M%S") <> "Z"
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
