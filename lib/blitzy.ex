defmodule Blitzy do
  use Application

  def start(_type, _args) do
    Blitzy.Supervisor.start_link(:ok)
  end

  def run(n_workers, url) when n_workers > 0 do
    worker_fun = fn -> Blitzy.Worker.start(url) end
    1..n_workers
      |> Enum.map(fn _ -> Task.async(worker_fun) end)
      |> Enum.map(&Task.await(&1, :infinity))
      |> parse_results
  end

  defp parse_results(results) do
    {successes, _failures} =
      results
        |> Enum.partition(fn x ->
          case x do
            {:ok, _} -> true
            _ -> false
          end
        end)

    total_workers = Enum.count(results)
    total_success = Enum.count(successes)

    data = successes |> Enum.map(fn {:ok, time} ->
      IO.inspect(time)
      time
    end)

    average_time = average(data)
    longest_time = Enum.max(data)

    IO.puts """
      Total workers #{total_workers}
      Average time #{average_time}
    """

  end

  defp average(list) do
    sum = Enum.sum(list)
    if (sum > 0) do
      sum / Enum.count(list)
    else
      0
    end
  end
end
