defmodule LatticeStripe.Drift do
  @moduledoc false
  # Internal dev tooling module — not part of the public LatticeStripe API.
  # Implements the core drift detection logic for comparing the Stripe OpenAPI spec
  # against the @known_fields registered in each LatticeStripe resource module.
  #
  # Used by Mix.Tasks.LatticeStripe.CheckDrift (Plan 02).

  alias LatticeStripe.ObjectTypes

  @spec_url "https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json"

  @doc false
  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(_opts \\ []) do
    with {:ok, spec} <- fetch_spec(),
         schemas <- resource_schemas(spec),
         object_map <- ObjectTypes.object_map() do
      # For each registered module, extract known_fields and compare
      modules_with_drift =
        object_map
        |> Enum.flat_map(fn {object_type, module} ->
          spec_entry = Map.get(schemas, object_type)

          if spec_entry == nil do
            []
          else
            spec_fields = spec_entry.fields
            spec_types = spec_entry.types

            case known_fields_for(module) do
              {:ok, known_fields} ->
                %{additions: additions, removals: removals} = compare(spec_fields, known_fields)

                if MapSet.size(additions) > 0 or MapSet.size(removals) > 0 do
                  [
                    %{
                      module: module,
                      object_type: object_type,
                      additions: additions,
                      removals: removals,
                      spec_types: spec_types
                    }
                  ]
                else
                  []
                end

              {:error, _reason} ->
                []
            end
          end
        end)

      # New resources: object types in spec not in registry
      registered_types = Map.keys(object_map) |> MapSet.new()
      spec_types_set = Map.keys(schemas) |> MapSet.new()
      new_resources = MapSet.difference(spec_types_set, registered_types) |> MapSet.to_list() |> Enum.sort()

      result = %{
        drift_count: length(modules_with_drift),
        modules: modules_with_drift,
        new_resources: new_resources
      }

      {:ok, result}
    end
  end

  @doc false
  @spec format_report(map()) :: String.t()
  def format_report(%{drift_count: 0, modules: [], new_resources: []}) do
    "No drift detected. @known_fields are up to date."
  end

  def format_report(%{drift_count: count, modules: modules, new_resources: new_resources}) do
    header =
      if count > 0 do
        "Drift detected in #{count} module#{if count == 1, do: "", else: "s"}:\n"
      else
        ""
      end

    module_sections =
      modules
      |> Enum.map(fn %{module: mod, object_type: object_type, additions: additions, removals: removals} = entry ->
        spec_types = Map.get(entry, :spec_types, %{})

        additions_lines =
          additions
          |> MapSet.to_list()
          |> Enum.sort()
          |> Enum.map(fn field ->
            type = Map.get(spec_types, field, "unknown")
            "  + #{field} (#{type})"
          end)

        removals_lines =
          removals
          |> MapSet.to_list()
          |> Enum.sort()
          |> Enum.map(fn field ->
            "  - #{field} (warning: in @known_fields but not in spec)"
          end)

        lines = additions_lines ++ removals_lines
        "#{inspect(mod)} (stripe object: \"#{object_type}\")\n#{Enum.join(lines, "\n")}"
      end)

    new_resources_section =
      if new_resources != [] do
        resource_lines = new_resources |> Enum.map(&"  #{&1}") |> Enum.join("\n")
        "\nNew resources not yet implemented (#{length(new_resources)}):\n#{resource_lines}"
      else
        ""
      end

    parts = Enum.reject([header <> Enum.join(module_sections, "\n\n"), new_resources_section], &(&1 == ""))
    Enum.join(parts, "\n")
  end

  @doc false
  @spec resource_schemas(map()) :: %{
          String.t() => %{fields: MapSet.t(), types: %{String.t() => String.t()}}
        }
  def resource_schemas(spec) do
    case get_in(spec, ["components", "schemas"]) do
      nil ->
        %{}

      schemas ->
        schemas
        |> Enum.reduce(%{}, fn {_schema_name, schema}, acc ->
          case get_in(schema, ["properties", "object", "enum"]) do
            [object_type] ->
              properties = get_in(schema, ["properties"]) || %{}
              fields = properties |> Map.keys() |> MapSet.new()

              types =
                properties
                |> Enum.map(fn {field, prop} ->
                  type =
                    cond do
                      is_map(prop) and Map.has_key?(prop, "type") -> prop["type"]
                      is_map(prop) and Map.has_key?(prop, "$ref") -> "object"
                      true -> "unknown"
                    end

                  {field, type}
                end)
                |> Map.new()

              Map.put(acc, object_type, %{fields: fields, types: types})

            _ ->
              acc
          end
        end)
    end
  end

  @doc false
  @spec known_fields_for(module()) :: {:ok, MapSet.t()} | {:error, term()}
  def known_fields_for(module) do
    case module.__info__(:compile)[:source] do
      nil ->
        {:error, :no_source}

      charlist ->
        source_path = List.to_string(charlist)

        case File.read(source_path) do
          {:ok, content} ->
            fields =
              case Regex.run(~r/@known_fields\s+~w\[([^\]]+)\]/s, content) do
                [_, fields_str] ->
                  fields_str
                  |> String.split(~r/\s+/, trim: true)
                  |> MapSet.new()

                nil ->
                  MapSet.new()
              end

            {:ok, fields}

          {:error, reason} ->
            {:error, {:file_read, reason}}
        end
    end
  end

  @doc false
  @spec compare(MapSet.t(), MapSet.t()) :: %{additions: MapSet.t(), removals: MapSet.t()}
  def compare(spec_fields, known_fields) do
    %{
      additions: MapSet.difference(spec_fields, known_fields),
      removals: MapSet.difference(known_fields, spec_fields)
    }
  end

  # Private: Download and parse the Stripe OpenAPI spec.
  # Starts a temporary Finch pool since this is dev tooling running outside
  # the application supervision tree (Mix task context).
  defp fetch_spec do
    finch_name = LatticeStripe.Drift.Finch

    case Finch.start_link(name: finch_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> throw({:finch_start_failed, reason})
    end

    result =
      :get
      |> Finch.build(@spec_url, [], nil)
      |> Finch.request(finch_name, receive_timeout: 30_000)

    case result do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, exception} ->
        {:error, exception}
    end
  catch
    {:finch_start_failed, reason} -> {:error, {:finch_start_failed, reason}}
  end
end
