defmodule ExTopologyTest do
  use ExUnit.Case
  doctest ExTopology

  test "version returns current version" do
    assert ExTopology.version() == "0.1.0"
  end
end
