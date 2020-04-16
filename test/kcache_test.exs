defmodule KCacheTest do
  use ExUnit.Case
  doctest KCache

  test "start cache" do
    {:ok, cache} = KCache.start_link(name: :sekiro)
    assert is_pid(cache) == true

    assert cache == GenServer.whereis(:sekiro)
  end

  test "set value" do
    {:ok, pid} = KCache.start_link(name: :sekiro)
    KCache.set(:sekiro, :ashina, :isshin, 100)
    state = :sys.get_state(pid)

    item = KCache.get(:sekiro, :ashina)

    order = Lookup.get!(state.order, {item.expires, item.key})

    assert item.value == :isshin
    assert item.key == :ashina
    assert order == :ashina
  end

  test "delete a value" do
    {:ok, _pid} = KCache.start_link(name: :sekiro)
    KCache.set(:sekiro, :ashina, :isshin, 100)
    KCache.set(:sekiro, :sculptor, :hatred, 100)
    assert KCache.item_count(:sekiro) == 2

    assert KCache.delete(:sekiro, :ashina) == true
    assert KCache.item_count(:sekiro) == 1
    assert KCache.get(:sekiro, :sculptor).value == :hatred
    assert KCache.get(:sekiro, :ashina) == nil
  end

  test "get expired item" do
    {:ok, _pid} = KCache.start_link(name: :sekiro)
    KCache.set(:sekiro, :ashina, :isshin, -100)
    KCache.set(:sekiro, :sculptor, :hatred, 100)
    assert KCache.item_count(:sekiro) == 2

    assert KCache.get(:sekiro, :sculptor).value == :hatred
    assert KCache.get(:sekiro, :ashina) == nil
  end

  test "gc the oldest item" do
    {:ok, _pid} = KCache.start_link(name: :sekiro)
    Enum.each(1..500, fn i -> KCache.set(:sekiro, i, i, 100) end)
    # sleep 2s
    :timer.sleep(2000)

    assert KCache.item_count(:sekiro) == 500

    assert KCache.prune(:sekiro) == 100

    assert KCache.get(:sekiro, 0) == nil
    assert KCache.get(:sekiro, 100) == nil
    assert KCache.get(:sekiro, 101).value == 101
    assert KCache.get(:sekiro, 500).value == 500

    assert KCache.item_count(:sekiro) == 400
  end

  # test "promoted item dont get pruned" do
  # 	{:ok, _pid} = KCache.start_link([name: :sekiro])
  # 	Enum.each(1..500, fn i -> KCache.set(:sekiro, i, i, 100) end)
  # 	:timer.sleep(2000) # sleep 2s

  # 	assert KCache.item_count(:sekiro) == 500

  # 	assert KCache.get(:sekiro, 0).value == 0

  # 	assert KCache.prune(:sekiro) == 100

  # 	assert KCache.get(:sekiro, 0).value == 0
  # 	assert KCache.get(:sekiro, 100) == nil
  # 	assert KCache.get(:sekiro, 101).value == 101
  # 	assert KCache.get(:sekiro, 500).value == 500

  # 	assert KCache.item_count(:sekiro) == 400
  # end

  test "handle_cast delete" do
    {:ok, pid} = KCache.start_link(name: :sekiro)
    state = :sys.get_state(pid)

    KCache.set(:sekiro, :ashina, :isshin, 100)
    # Before
    item = KCache.get(:sekiro, :ashina)
    order = Lookup.get!(state.order, {item.expires, item.key})
    assert order == :ashina

    # After
    {:noreply, ^state} = KCache.handle_cast({:delete, item}, state)
    assert Lookup.contains?(state.order, {item.expires, item.key}) == false
  end

  test "overwrite existing value" do
    {:ok, pid} = KCache.start_link(name: :sekiro)
    state = :sys.get_state(pid)

    KCache.set(:sekiro, :ashina, :isshin, 100)
    item = KCache.get(:sekiro, :ashina)
    order = Lookup.get!(state.order, {item.expires, item.key})

    assert item.value == :isshin
    assert item.key == :ashina
    assert order == :ashina

    KCache.set(:sekiro, :ashina, :genichiro, 200)
    new_item = KCache.get(:sekiro, :ashina)

    :timer.sleep(5000)

    assert Lookup.get!(state.order, {item.expires, item.key}) == nil
    order = Lookup.get!(state.order, {new_item.expires, new_item.key})

    assert new_item.value == :genichiro
    assert new_item.key == :ashina
    assert order == :ashina
  end

  test "prune" do
    {:ok, pid} = KCache.start_link(name: :sekiro)
    state = :sys.get_state(pid)

    KCache.set(:sekiro, :ashina, :isshin, 100)
    KCache.set(:sekiro, :sculptor, :hatred, 200)

    :timer.sleep(2000)

    assert Lookup.len(state.lookup) == 2
    assert Lookup.len(state.order) == 2

    assert KCache.prune(:sekiro) == 2
    assert Lookup.len(state.lookup) == 0
    assert Lookup.len(state.order) == 0
  end
end
