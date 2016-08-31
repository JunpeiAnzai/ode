defmodule Ode.Repo do
  use Ecto.Repo, otp_app: :ode, adapter: Sqlite.Ecto
end
