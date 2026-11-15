defimpl Mudbrick.Object, for: Mudbrick.Document do
  @initial_generation "00000"
  @free_entries_first_generation "65535"

  alias Mudbrick.Document
  alias Mudbrick.Object

  def to_iodata(%Document{objects: raw_objects} = doc) do
    header = ["%PDF-", doc.pdf_version, "\n%", <<0xE2, 0xE3, 0xCF, 0xD3>>]
    objects = raw_objects |> Enum.reverse() |> Enum.map(&Object.to_iodata/1)
    sections = [header | objects]

    # A file identifier is mandatory in PDF/A and harmless elsewhere; deriving
    # it from the content keeps output deterministic.
    id = :md5 |> :crypto.hash(objects) |> Base.encode16()

    trailer =
      Object.to_iodata(%{
        Size: length(objects) + 1,
        Root: Document.catalog(doc).ref,
        ID: [id, id]
      })

    [
      Enum.intersperse(sections, ?\n),
      "\nxref\n",
      ["0 ", Kernel.to_string(length(objects) + 1), "\n"],
      offsets(sections),
      "\ntrailer\n",
      trailer,
      "\nstartxref\n",
      offset(sections),
      "\n%%EOF"
    ]
  end

  defp offsets(sections) do
    {_, retval} =
      for section <- sections, reduce: {[], []} do
        {[], []} ->
          {
            [section],
            [padded_offset([]), " ", @free_entries_first_generation, " f "]
          }

        {past_sections, iolist} ->
          {
            [section | past_sections],
            [iolist, "\n", padded_offset(past_sections), " ", @initial_generation, " n "]
          }
      end

    retval
  end

  defp padded_offset(strings) do
    strings
    |> offset()
    |> String.pad_leading(10, "0")
  end

  defp offset(strings) do
    strings
    |> Enum.map(&IO.iodata_length([&1, "\n"]))
    |> Enum.sum()
    |> Kernel.to_string()
  end
end
