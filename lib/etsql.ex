defmodule ETSql do
  @moduledoc """
  `ETSql` is a micro-DSL for working with ETS via simple SQL-ish strings.
  """

  @create_rx ~r/^CREATE\s+TABLE\s+(\w+)\s*\((.*?)\)\s*(?:\[(\w+)\])?\s*(?:key\s*\((\w+)(?:\s+(\w+))?\))?\s*;?$/ix

  @insert_rx ~r/^INSERT\s+INTO\s+(\w+)\s*\((.*?)\)\s*VALUES\s*\((.*?)\)\s*;?$/ix

  @doc """
  Executes the given SQL statement.

  ## Examples

      iex> sql_create = "CREATE TABLE user (id, name, email) [set] key (id);"
          "CREATE TABLE user (id, name, email) [set] key (id);"
      iex> ETSql.exec(sql_create)
          {:ok, "Table user created ([:id, :name, :email]) type :set, key :id/nil"})
      iex> ETSql.exec("INSERT INTO user (id, name) VALUES (1, 'Alice');")
          {:ok, "Inserted"}
  """
  @spec exec(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def exec("CREATE TABLE" <> _ = sql), do: sql |> clean_sql() |> create_table()
  def exec("INSERT INTO" <> _ = sql), do: sql |> clean_sql() |> insert_into()
  def exec(_), do: {:error, "Unsupported SQL statement"}

  defp create_table(sql) do
    with {:ok, name, cols, type, key_col, key_typ} <- parse_create(sql),
         {:ok, msg} <- ensure_table(name, cols, type, key_col, key_typ) do
      {:ok, msg}
    else
      {:error, _} = err -> err
    end
  end

  defp parse_create(sql) do
    case Regex.run(@create_rx, sql) do
      nil ->
        {:error, "Invalid SQL syntax"}

      [_full | caps] ->
        name = Enum.at(caps, 0)
        col_str = Enum.at(caps, 1)
        raw_typ = Enum.at(caps, 2) || "set"
        raw_key = Enum.at(caps, 3)
        raw_ktyp = Enum.at(caps, 4)

        {:ok, name, split_columns(col_str), String.to_atom(raw_typ),
         raw_key && String.to_atom(raw_key), raw_ktyp && String.to_atom(raw_ktyp)}
    end
  end

  defp ensure_table(name, cols, type, key_col, key_typ) do
    fields = Enum.map(cols, &col_name/1)
    tab_atom = String.to_atom(name)

    try do
      :ets.new(tab_atom, [:named_table, type, {:keypos, 1}])

      {:ok,
       "Table #{name} created (#{inspect(fields)}) type #{type}, key " <>
         "#{inspect(key_col)}/#{inspect(key_typ)}"}
    rescue
      ArgumentError -> {:error, "Table #{name} already exists"}
    end
  end

  defp insert_into(sql) do
    with {:ok, tab, cols, vals} <- parse_insert(sql),
         :ok <- validate_length(cols, vals),
         :ok <- validate_key(vals),
         :ok <- do_insert(tab, cols, vals) do
      {:ok, "Inserted"}
    else
      {:error, _} = err -> err
    end
  end

  defp parse_insert(sql) do
    case Regex.run(@insert_rx, sql) do
      nil ->
        {:error, "Invalid INSERT SQL syntax"}

      [_full, tbl, col_csv, val_csv] ->
        {:ok, tbl, split_csv(col_csv), parse_values(val_csv)}
    end
  end

  defp clean_sql(sql) do
    sql
    |> String.trim()
    |> String.replace(~r/[\n\r]+/, " ")
    |> String.replace(~r/\s+/, " ")
  end

  # column helpers
  defp split_columns(csv), do: csv |> split_csv() |> Enum.map(&split_col/1)

  defp split_col(col) do
    case String.split(String.trim(col), ~r/\s+/, parts: 2) do
      [n, t] -> {n, t}
      [n] -> {n, nil}
    end
  end

  defp col_name({n, _}), do: String.to_atom(n)

  # value helpers
  defp split_csv(str), do: str |> String.split(",") |> Enum.map(&String.trim/1)

  defp parse_values(csv) do
    Regex.split(~r/,(?=(?:[^']*'[^']*')*[^']*$)/, csv)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&cast/1)
  end

  defp cast(v) do
    v = String.trim(v, "'")

    case Integer.parse(v) do
      {n, ""} -> n
      _ -> v
    end
  end

  # validation
  defp validate_length(cols, vals) when length(cols) == length(vals), do: :ok
  defp validate_length(_, _), do: {:error, "Column/value count mismatch"}

  defp validate_key([nil | _]), do: {:error, "Key cannot be NULL"}
  defp validate_key(_), do: :ok

  # insert
  defp do_insert(tab, [_key_col | data_cols], [key_val | data_vals]) do
    tab_atom = String.to_atom(tab)

    record =
      [key_val | make_tuple(data_cols, data_vals)]
      |> List.to_tuple()

    :ets.insert(tab_atom, record)
    :ok
  end

  defp make_tuple(cols, vals) do
    cols
    |> Enum.zip(vals)
    |> Enum.map(fn {c, v} -> {String.to_atom(c), v} end)
  end
end
