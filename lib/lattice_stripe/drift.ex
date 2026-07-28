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
        new_resources: new_resources,
        stats: aggregate_stats(modules_with_drift, new_resources)
      }

      {:ok, result}
    end
  end

  @doc false
  @spec format_summary(map()) :: String.t()
  def format_summary(result) do
    stats = Map.get(result, :stats) || aggregate_stats(result.modules, result.new_resources)

    """
    ## Drift summary (#{Date.utc_today()})

    | Category | Count |
    |----------|------:|
    | Modules with drift | #{stats.modules_with_drift} |
    | Actionable field additions (`+`) | #{stats.addition_fields} in #{stats.modules_with_additions} module(s) |
    | Spec mismatch warnings (`-`) | #{stats.removal_fields} in #{stats.modules_with_removals} module(s) |
    | Unmodeled Stripe resources | #{stats.unmodeled_resources} |

    **Triage:** Act on `+` additions for modules adopters use. Defer bulk `-` warnings (OpenAPI shape noise). New resource types need adopter pull — not a release blocker.

    Run locally for full detail: `mix lattice_stripe.check_drift`
    """
    |> String.trim()
  end

  @doc false
  @spec aggregate_stats(list(), list()) :: map()
  def aggregate_stats(modules, new_resources) do
    addition_fields =
      modules
      |> Enum.map(&MapSet.size(&1.additions))
      |> Enum.sum()

    removal_fields =
      modules
      |> Enum.map(&MapSet.size(&1.removals))
      |> Enum.sum()

    %{
      modules_with_drift: length(modules),
      modules_with_additions: Enum.count(modules, &(MapSet.size(&1.additions) > 0)),
      modules_with_removals: Enum.count(modules, &(MapSet.size(&1.removals) > 0)),
      addition_fields: addition_fields,
      removal_fields: removal_fields,
      unmodeled_resources: length(new_resources)
    }
  end

  @doc false
  @spec format_report(map()) :: String.t()
  def format_report(%{drift_count: 0, modules: [], new_resources: []}) do
    "No drift detected. @known_fields are up to date."
  end

  def format_report(result) do
    modules = result.modules
    new_resources = result.new_resources
    stats = Map.get(result, :stats) || aggregate_stats(modules, new_resources)

    summary =
      """
      Drift summary: #{stats.modules_with_drift} module(s), \
      #{stats.addition_fields} actionable addition(s), \
      #{stats.removal_fields} spec-mismatch warning(s), \
      #{stats.unmodeled_resources} unmodeled resource(s).
      """

    {with_additions, _warnings_only} =
      Enum.split_with(modules, &(MapSet.size(&1.additions) > 0))

    additions_section =
      if with_additions == [] do
        ""
      else
        header = "Actionable additions (Stripe spec fields missing from @known_fields):\n"

        body = Enum.map_join(with_additions, "\n\n", &format_module_additions/1)

        header <> body
      end

    warnings_section =
      modules
      |> Enum.filter(&(MapSet.size(&1.removals) > 0))
      |> case do
        [] ->
          ""

        warning_modules ->
          header =
            "Spec mismatch warnings (@known_fields not on OpenAPI object schema — often noise):\n"

          body = Enum.map_join(warning_modules, "\n\n", &format_module_removals/1)

          header <> body
      end

    new_resources_section = format_new_resources(new_resources)

    parts =
      [summary, additions_section, warnings_section, new_resources_section]
      |> Enum.reject(&(&1 == ""))

    Enum.join(parts, "\n\n")
  end

  defp format_module_additions(%{
         module: mod,
         object_type: object_type,
         additions: additions,
         spec_types: spec_types
       }) do
    lines =
      additions
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.map(fn field ->
        type = Map.get(spec_types, field, "unknown")
        "  + #{field} (#{type})"
      end)

    "#{inspect(mod)} (stripe object: \"#{object_type}\")\n#{Enum.join(lines, "\n")}"
  end

  defp format_module_removals(%{module: mod, object_type: object_type, removals: removals}) do
    lines =
      removals
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.map(&"  - #{&1} (warning: in @known_fields but not in spec)")

    "#{inspect(mod)} (stripe object: \"#{object_type}\")\n#{Enum.join(lines, "\n")}"
  end

  defp format_new_resources([]), do: ""

  defp format_new_resources(new_resources) do
    resource_lines = Enum.map_join(new_resources, "\n", &"  #{&1}")
    "Unmodeled Stripe resources (#{length(new_resources)}):\n#{resource_lines}"
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
    # Both word-sigil delimiters: ~w[...] and ~w(...) are both in use across lib/.
    case Regex.run(~r/@known_fields\s+~w[\[(]([^\])]+)[\])]/s, content) do
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
