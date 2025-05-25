defmodule ETSqlTest do
  use ExUnit.Case, async: true
  alias ETSql

  defp drop(tab) do
    tab_atom = String.to_atom(tab)
    :ets.delete(tab_atom)
  rescue
    ArgumentError -> :ok
  end

  describe "CREATE TABLE" do
    setup _ctx do
      on_exit(fn ->
        drop("users")
        drop("dup")
      end)

      :ok
    end

    test "creates a fresh table" do
      assert {:ok, _msg} =
               ETSql.exec("CREATE TABLE users (id, name) [set] key (id);")

      assert :ets.info(:users) != :undefined
    end

    test "fails when the table already exists" do
      ETSql.exec("CREATE TABLE dup (id) key (id);")

      assert {:error, "Table dup already exists"} =
               ETSql.exec("CREATE TABLE dup (id) key (id);")
    end
  end

  describe "INSERT INTO" do
    setup _ctx do
      ETSql.exec("CREATE TABLE users (id, name, email) [set] key (id);")

      on_exit(fn -> drop("users") end)
      :ok
    end

    test "inserts a valid row" do
      assert {:ok, "Inserted"} =
               ETSql.exec("INSERT INTO users (id, name) VALUES (1, 'Alice');")

      assert [{1, {:name, "Alice"}}] = :ets.tab2list(:users)
    end

    test "fails when column/value counts differ" do
      assert {:error, "Column/value count mismatch"} =
               ETSql.exec("INSERT INTO users (id, name) VALUES (1);")
    end
  end
end
