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
          drift_entry(object_type, module, schemas)
        end)

      # New resources: object types in spec not in registry
      registered_types = Map.keys(object_map) |> MapSet.new()
      spec_types_set = Map.keys(schemas) |> MapSet.new()

      new_resources =
        MapSet.difference(spec_types_set, registered_types) |> MapSet.to_list() |> Enum.sort()

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
      |> Enum.map(fn %{
                       module: mod,
                       object_type: object_type,
                       additions: additions,
                       removals: removals
                     } = entry ->
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
        resource_lines = Enum.map_join(new_resources, "\n", &"  #{&1}")
        "\nNew resources not yet implemented (#{length(new_resources)}):\n#{resource_lines}"
      else
        ""
      end

    parts =
      Enum.reject(
        [header <> Enum.join(module_sections, "\n\n"), new_resources_section],
        &(&1 == "")
      )

    Enum.join(parts, "\n")
  end

  @doc false
  @spec resource_schemas(map()) :: %{
          String.t() => %{fields: MapSet.t(), types: %{String.t() => String.t()}}
        }
  def resource_schemas(spec) do
    case get_in(spec, ["components", "schemas"]) do
      nil -> %{}
      schemas -> Enum.reduce(schemas, %{}, &accumulate_resource_schema/2)
    end
  end

  @doc false
  @spec known_fields_for(module()) :: {:ok, MapSet.t()} | {:error, term()}
  def known_fields_for(module) do
    with {:ok, source_path} <- module_source_path(module),
         {:ok, content} <- File.read(source_path) do
      {:ok, parse_known_fields(content)}
    end
  end

  defp module_source_path(module) do
    case module.__info__(:compile)[:source] do
      nil -> {:error, :no_source}
      charlist -> {:ok, resolve_source_path(charlist)}
    end
  end

  defp parse_known_fields(content) do
    case Regex.run(~r/@known_fields\s+~w\[([^\]]+)\]/s, content) do
      [_, fields_str] ->
        fields_str |> String.split(~r/\s+/, trim: true) |> MapSet.new()

      nil ->
        MapSet.new()
    end
  end

  # Resolves the compile-time absolute source path to a readable file.
  # In CI with a restored build cache the original absolute path may not exist
  # (different runner, different checkout location). Fall back to a path
  # derived from the current project root so cached builds still work.
  defp drift_entry(object_type, module, schemas) do
    case Map.get(schemas, object_type) do
      nil ->
        []

      %{fields: spec_fields, types: spec_types} ->
        case known_fields_for(module) do
          {:ok, known_fields} ->
            build_drift_module_entry(module, object_type, spec_fields, known_fields, spec_types)

          {:error, _reason} ->
            []
        end
    end
  end

  defp build_drift_module_entry(module, object_type, spec_fields, known_fields, spec_types) do
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
  end

  defp accumulate_resource_schema({_schema_name, schema}, acc) do
    case get_in(schema, ["properties", "object", "enum"]) do
      [object_type] ->
        properties = get_in(schema, ["properties"]) || %{}
        fields = properties |> Map.keys() |> MapSet.new()
        types = properties |> property_types_map()
        Map.put(acc, object_type, %{fields: fields, types: types})

      _ ->
        acc
    end
  end

  defp property_types_map(properties) do
    Map.new(properties, fn {field, prop} -> {field, property_type(prop)} end)
  end

  defp property_type(prop) when is_map(prop) do
    cond do
      Map.has_key?(prop, "type") -> prop["type"]
      Map.has_key?(prop, "$ref") -> "object"
      true -> "unknown"
    end
  end

  defp property_type(_), do: "unknown"

  defp resolve_source_path(charlist) do
    absolute = List.to_string(charlist)

    if File.exists?(absolute) do
      absolute
    else
      project_root =
        Mix.Project.build_path()
        |> Path.join("../../")
        |> Path.expand()

      # Strip the leading "/" and re-join under the current project root.
      rel = Path.relative_to(absolute, "/")
      Path.join(project_root, rel)
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

    with :ok <- start_finch(finch_name),
         {:ok, response} <- do_request(finch_name) do
      Jason.decode(response.body)
    end
  end

  defp start_finch(name) do
    case Finch.start_link(name: name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, {:finch_start_failed, reason}}
    end
  end

  defp do_request(finch_name) do
    :get
    |> Finch.build(@spec_url, [], nil)
    |> Finch.request(finch_name, receive_timeout: 30_000)
    |> case do
      {:ok, %Finch.Response{status: 200} = resp} -> {:ok, resp}
      {:ok, %Finch.Response{status: status}} -> {:error, {:http_error, status}}
      {:error, exception} -> {:error, exception}
    end
  end
end
