case OAAS.Utils.start_db() do
  :ok -> :noop
  {:error, {:already_started, _pid}} -> :noop
  {:error, reason} -> throw(reason)
end

Logger.configure(level: :warn)
ExUnit.start()
