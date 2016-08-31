defmodule TokensServer do
  def start_link do
    Agent.start_link(fn -> %{} end)
  end

  def put(pid, key, value) do
    Agent.update(pid, &Map.put(&1, key, value))
  end

  def get(pid, key) do
    Agent.get(pid, &Map.get(&1, key))
  end
end

