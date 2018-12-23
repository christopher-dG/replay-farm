defmodule ReplayFarm.Worker do
  @moduledoc "Workers are clients that can complete jobs."

  alias ReplayFarm.Job

  @table "workers"

  @enforce_keys [:id, :last_poll, :created_at, :updated_at]
  defstruct @enforce_keys ++ [:last_job, :current_job_id]

  @type t :: %__MODULE__{
          # Worker ID.
          id: binary,
          # Last poll time (unix).
          last_poll: integer,
          # Last job time (unix).
          last_job: integer,
          # Current job.
          current_job_id: integer,
          # Worker creation time.
          created_at: integer,
          # Worker update time.
          updated_at: integer
        }

  @json_columns []

  use ReplayFarm.Model

  @online_threshold 30 * 1000

  @doc "Gets all available workers (online + not busy)."
  @spec get_available :: {:ok, [t]} | {:error, term}
  def get_available do
    query(
      "SELECT * FROM #{@table} WHERE current_job_id IS NULL AND ABS(?1 - last_poll) <= ?2",
      x: System.system_time(:millisecond),
      x: @online_threshold
    )
  end

  @doc "Gets the worker's currently assigned job."
  def get_assigned(_w)

  @spec get_assigned(t) :: Job.t() | nil
  def get_assigned(%__MODULE__{current_job_id: nil}) do
    {:ok, nil}
  end

  def get_assigned(%__MODULE__{current_job_id: id}) do
    ass = Job.status(:assigned)

    case Job.get(id) do
      {:ok, %Job{status: ^ass} = j} -> {:ok, j}
      {:ok, _j} -> {:ok, nil}
      {:error, err} -> {:error, err}
    end
  end

  @spec get_assigned(binary) :: {:ok, Job.t() | nil} | {:error, term}
  def get_assigned(id) do
    id
    |> get()
    |> get_assigned()
  end

  @doc "Retrieves a worker, or creates a new one."
  @spec get_or_put(binary) :: {:ok, t} | {:error, term}
  def get_or_put(id) do
    case get(id) do
      {:ok, nil} ->
        notify("inserting new worker `#{id}`")
        put(id: id)

      {:ok, w} ->
        {:ok, w}

      {:error, err} ->
        {:error, err}
    end
  end

  @doc "Chooses an online worker by LRU."
  @spec get_lru :: t | nil
  def get_lru do
    case get_available() do
      {:ok, []} ->
        {:ok, nil}

      {:ok, ws} ->
        {:ok,
         ws
         |> Enum.sort_by(fn w -> w.last_job || 0 end)
         |> hd()}

      {:error, err} ->
        {:error, err}
    end
  end
end
