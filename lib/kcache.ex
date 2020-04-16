defmodule KCache do
	use GenServer

	def start_link(opts) do
		GenServer.start_link(__MODULE__, opts, opts)
	end

	@impl true
	def init(args) do
		name = args[:name]
		order = String.to_atom("#{name}_order")
		lookup = String.to_atom("#{name}_lookup")

		config = %Configuration{
			to_prune: args[:to_prune] || 100,
			max_size: args[:max_size] || 1000
		}

		{:ok, _pid} = Lookup.start_link([name: order, type: :ordered_set]) # keep track of most recent used item
		{:ok, _pid} = Lookup.start_link([name: lookup, type: :set]) # cache item lookup

		{:ok, %{order: order, lookup: lookup, name: name, config: config}}
	end

	# handle_cast
	@impl true
	def handle_cast({:set, {key, value, duration}}, state) do
		expires = now!() |> DateTime.add(duration) |> DateTime.to_unix()
		item = %Lookup.Item{key: key, value: value, expires: expires}
		
		if Lookup.contains?(state.lookup, key) == true do
			existing = Lookup.get!(state.lookup, key)
			GenServer.cast(self(), {:delete, existing})
		end

		Lookup.insert(state.lookup, key, item)
		GenServer.cast(self(), {:promote, item})

		{:noreply, state}
	end

	@impl true
	def handle_cast({:promote, item}, state) do
		Lookup.insert(state.order, {item.expires, item.key}, item.key)
		{:noreply, state}
	end

	@impl true
	def handle_cast({:delete, item}, state) do
		if Lookup.contains?(state.order, {item.expires, item.key}) == true do
			Lookup.remove(state.order, {item.expires, item.key})
		end
		
		{:noreply, state}
	end

	# handle_call
	@impl true
	def handle_call(:ping, _from, state) do
		{:reply, state, state}
	end

	@impl true
	def handle_call({:get, key}, _from, state) do
		with {:ok, item} <- Lookup.get(state.lookup, key)
		do
			item = case item.expires < now!() |> DateTime.to_unix() do
				false -> item
				true -> # remove expired item and return nil
					Lookup.remove(state.lookup, key)
					GenServer.cast(self(), {:delete, item})
					nil
			end
			
			{:reply, item, state}
		else
			_ -> {:reply, nil, state}
		end
	end

	@impl true
	def handle_call({:delete, key}, _from, state) do
		deleted? = case Lookup.take(state.lookup, key) do
			nil -> false
			{:ok, item} -> GenServer.cast(self(), {:delete, item}); true
		end

		{:reply, deleted?, state}
	end

	@impl true
	def handle_call(:prune, _from, state) do
		dropped = Enum.reduce_while(1..state.config.to_prune, 0, fn _, counter ->
			with {:ok, {expires, key}} <- Lookup.head(state.order)
			do
				Lookup.remove(state.lookup, key)
				Lookup.remove(state.order, {expires, key})
				{:cont, counter + 1}
			else
				_ -> {:halt, counter}
			end
		end)
		{:reply, dropped, state}
	end

	@impl true
	def handle_call(:item_count, _from, state), do: {:reply, Lookup.len(state.lookup), state}

	def delete(cache, key) do
		GenServer.call(cache, {:delete, key})
	end

	def item_count(cache) do
		GenServer.call(cache, :item_count)
	end

	def set(cache, key, value, duration) do
		GenServer.cast(cache, {:set, {key, value, duration}})
	end

	def fetch(cache, fetch_fn, key, value, duration) do
		# GenServer.call(cache, {:fetch, {fetch_fn, key, value, duration}})
	end

	def get(cache, key) do
		GenServer.call(cache, {:get, key})
	end

	def prune(cache) do
		GenServer.call(cache, :prune)
	end

	defp now!(), do: DateTime.now!("Etc/UTC")
end
