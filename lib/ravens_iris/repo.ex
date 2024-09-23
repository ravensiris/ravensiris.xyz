defmodule RavensIris.Repo do
  use Ecto.Repo,
    otp_app: :ravens_iris,
    adapter: Ecto.Adapters.Postgres
end
