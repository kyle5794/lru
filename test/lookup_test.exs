defmodule LookupTest do
  use ExUnit.Case
  doctest Lookup

  test "name" do
    {:ok, x} = Lookup.start_link(name: :sekiro)
    assert Lookup.name(x) == :sekiro
  end

  # use GenServer

  test "start lookup" do
    {:ok, x} = Lookup.start_link(name: :sekiro)

    y = GenServer.whereis(:sekiro)

    assert x == y
  end

  test "insert value" do
    {:ok, x} = Lookup.start_link(name: :sekiro)
    assert Lookup.len(x) == 0

    Lookup.insert(x, :isshin, :ashina)
    assert Lookup.len(x) == 1

    assert Lookup.contains?(x, :isshin) == true
    assert Lookup.get(x, :isshin) == {:ok, :ashina}
    assert Lookup.get!(x, :isshin) == :ashina
  end
end
