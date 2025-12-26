defmodule ExTopologyTest do
  use ExUnit.Case
  doctest ExTopology

  test "version returns current version" do
    assert ExTopology.version() == "0.2.0"
  end
end
