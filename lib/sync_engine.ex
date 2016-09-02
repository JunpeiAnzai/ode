defmodule SyncEngine do
  def apply_differences do
    require Logger
    Logger.debug "Applying differences"

    try do
      IO.puts "try"
      throw(:x)
    catch
      :x -> IO.puts "catch x"
    end
  end
end
