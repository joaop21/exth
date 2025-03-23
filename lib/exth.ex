defmodule Exth do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
end
