use Mix.Config
defmodule Blitzy.CLI do
  require Logger


  def main(args) do
    Application.get_env(:blitzy, :master_node)
      |> Node.start

    Application.get_env(:blitzy, :slave_nodes)
      |> Enum.each(&Node.connect(&1))

    args
      |> parse_args
      |> process_options
  end

  defp parse_args(args) do
    OptionParser.parse(args, aliases: [n: :requests], strict: [requests: :integer])
  end

  defp process_options(options) do
    case options do
      {[requests: n], [url], []} ->
        do_requests(n, url)
      _ ->
        do_help
    end
  end

  defp do_help do
    IO.puts """
      Usage:
      blitzy -n [requests] [url]
      Options:
      -n, [--requests]
      # Number of requests
      Example:
      ./blitzy -n 100 http://www.bieberfever.com
    """
    System.halt(0)
  end

  defp do_requests(n_requests, url) do

    nodes = Application.get_env(:blitzy, :slave_nodes)
    Logger.info "Pummeling #{url} with #{n_requests} requests"
    total_nodes = Enum.count(nodes)
    req_per_node = div(n_requests, total_nodes)

    nodes
      |> Enum.flat_map(fn node ->
        1..req_per_node |> Enum.map(fn _ ->
          Task.Supervisor.async({Blitzy.TasksSupervisor, node},
            Blitzy.Worker, :start, [url]
          )
        end)
      end)
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
