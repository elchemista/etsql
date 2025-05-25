# ETSql

A **tiny SQL-flavoured wrapper** around Erlang ETS.
It lets you spin up named ETS tables and push rows into them with just two
statements:

* `CREATE TABLE …`
* `INSERT INTO … VALUES …`

That’s it—no dependencies, no macros, just a pinch of regex and pattern
matching.

** This is a work in progress. **

Why? I'm just tired writing ETS match structures and I want something simpler that everyone knows.
It just become too much work to write the match structures by hand.

```elixir
 match = [
      {
        {{:"$1", :"$2", :"$3", :"$4", :"$5"}, :_},
        build_key_pattern(key),
        [:"$$"]
      }
    ]
```

---

## Features

| verb             | example                                             | effect                                                                                                                                             |
| ---------------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **CREATE TABLE** | `CREATE TABLE users (id, name) [set] key (id);`     | Creates an ETS named table `:users` of type `:set` with `id` in tuple position 1. Duplicate names return `{:error, "Table users already exists"}`. |
| **INSERT INTO**  | `INSERT INTO users (id, name) VALUES (1, 'Alice');` | Inserts `{1, {name: "Alice"}}` into `:users`. Column/value count mismatch is rejected.                                                             |

*Table type* (`[set]`, `[ordered_set]`, …) and *column types* (`INT`,
`VARCHAR`, …) are currently optional and ignored, ready for future
type-checking.

---

## Installation

Add **`etsql`** to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:etsql, github: "elchemista/etsql", branch: "main"}
  ]
end
```

Then run `mix deps.get`.

---

## Quick start

```elixir
iex> ETSql.exec "CREATE TABLE users (id, name) [set] key (id);"
{:ok, "Table users created ([:id, :name]) type set, key :id/nil"}

iex> ETSql.exec "INSERT INTO users (id, name) VALUES (1, 'Alice');"
{:ok, "Inserted"}

iex> :ets.tab2list :users
[{1, {:name, "Alice"}}]
```
---

## Roadmap / TODO

* Basic type validation (`INT`, `VARCHAR(n)`, etc.). __But I'm not sure if I really need it.__
* `UPDATE` / `DELETE` support
* Simple `SELECT` with `WHERE` on the key
* Hex publishing & ExDoc guides

Pull requests welcome!
