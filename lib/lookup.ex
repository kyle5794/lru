defmodule Lookup do
	defmodule Item do
		defstruct [
			:key,
			:expires,
			:value,
		]
	end
	use Agent

	@properties [:name, :len]

	def start_link(opts) do
		name = opts[:name]
		type = opts[:type]
		:ets.new(name, [type, :named_table, :public, read_concurrency: true, write_concurrency: true])
		Agent.start_link(fn -> %{name: name, len: 0} end, opts)
	end

	def insert(agent, key, node) do
		if :ets.insert(name(agent), {key, node}) == true do
			increase_len(agent)
		end
	end
	def contains?(agent, key), do: :ets.member(name(agent), key)

	def remove(agent, key) do
		:ets.delete(name(agent), key)
		decrease_len(agent)
	end

	def get(agent, key) do
		case :ets.lookup(name(agent), key) do
			[{_key, node}] -> {:ok, node}
			[] -> nil
		end
	end

	def get!(agent, key) do
		case get(agent, key) do
			{:ok, node} -> node
			nil -> nil
		end
	end

	def take(agent, key) do
		case :ets.take(name(agent), key) do
			[{_key, node}] ->
				decrease_len(agent)
				{:ok, node}
			[] -> nil
		end
	end

	def take!(agent, key) do
		case take(agent, key) do
			nil -> nil
			{:ok, node} -> {:ok, node}
		end
	end

	def head(agent) do 
		case :ets.first(name(agent)) do
			:"$end_of_table" -> nil
			key -> {:ok, key}
		end
	end

	def head!(agent) do
		case head(agent) do
			{:ok, key} -> key
			nil -> nil
		end
	end

	def tail(agent) do 
		case :ets.last(name(agent)) do
			:"$end_of_table" -> nil
			key -> {:ok, key}
		end
	end

	def tail!(agent) do
		case tail(agent) do
			{:ok, key} -> key
			nil -> nil
		end
	end

	defp increase_len(agent) do
		Agent.update(agent, fn state -> %{state | len: state.len + 1} end)
	end
	defp decrease_len(agent) do
		Agent.update(agent, fn state -> %{state | len: state.len - 1} end)
	end

	for property <- @properties do
		def unquote(property)(agent), do: Agent.get(agent, &Map.get(&1, unquote(property)))
	end

end