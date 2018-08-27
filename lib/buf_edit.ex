defmodule BufEdit do
  @moduledoc """
  Programmable buffer editor, similar in concept to [ed](https://en.wikipedia.org/wiki/Ed_(text_editor)).

  `BufEdit` reads a file into memory and provides a flexible API for editing it and writing
  it back to a file.

  Consider the following mix.exs file:

  ```elixir
  defmodule MyApp.MixProject do
    use Mix.Project

    def project do
      [
        app: :my_app,
        version: "0.1.0",
        elixir: "~> 1.6",
        start_permanent: Mix.env() == :prod,
        deps: deps()
      ]
    end

    # Run "mix help compile.app" to learn about applications.
    def application do
      [
        extra_applications: [:logger]
      ]
    end

    # Run "mix help deps" to learn about dependencies.
    defp deps do
      [
        # {:dep_from_hexpm, "~> 0.3.0"},
        # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      ]
    end
  end
  ```

  We'll use `BufEdit` to load the file and jump to a line matching a regular
  expression:

  ```elixir
  iex> buf = BufEdit.load("mix.exs")
  iex> buf = BufEdit.search(buf, ~r/defp deps/, :down)
  %BufEdit{
    col: 1,
    filename: "test/fixtures/mix.exs",
    lines: ["defmodule MyApp.MixProject do", "  use Mix.Project", ""],
    line_num: 22,
    status: :ok
  }
  ```

  (The `lines` key value above has been abbreviated in this example)

  If the line is found, the returned `%BufEdit{}` has a `:status` key set to `:ok`,
  and the `:line_num` key is set to the new line number.

  Now, let's say we want to remove the two comment lines from the dependencies
  list and add a new dependency:

  ```elixir
  iex> buf = BufEdit.search(buf, ~r/^\s*#/, :down)
  %BufEdit{
    col: 1,
    filename: "test/fixtures/mix.exs",
    lines: ["defmodule MyApp.MixProject do", "  use Mix.Project", ""],
    line_num: 24,
    status: :ok
  }
  ```

  Now, we're at line 24. If you want to see line 24, use `line/1`:

  ```elixir
  iex> BufEdit.line(buf)
  "      # {:dep_from_hexpm, \\"~> 0.3.0\\"},"
  ```

  Yep, that's the line we're looking for.

  The next step is to delete the two comments:

  ```elixir
  iex> buf = BufEdit.delete_lines(buf, 2)
  %BufEdit{
    col: 1,
    filename: "test/fixtures/mix.exs",
    lines: ["defmodule MyApp.MixProject do", "  use Mix.Project", ""],
    line_num: 24,
    status: :ok
  }
  iex> BufEdit.line(buf)
  "    ]"
  ```

  Now that the lines are deleted, we're ready to add the new dependency:

  ```elixir
  iex> buf = BufEdit.insert_line(buf, "      {:buffer, \\"~> 0.1.0\\"}")
  iex> BufEdit.dump(buf) |> IO.puts()
  defmodule MyApp.MixProject do
    use Mix.Project

    def project do
      [
        app: :my_app,
        version: "0.1.0",
        elixir: "~> 1.6",
        start_permanent: Mix.env() == :prod,
        deps: deps()
      ]
    end

    # Run "mix help compile.app" to learn about applications.
    def application do
      [
        extra_applications: [:logger]
      ]
    end

    # Run "mix help deps" to learn about dependencies.
    defp deps do
      [
        {:buffer, "~> 0.1.0"}
      ]
    end
  end
  ```

  Our new dependency is added! Now it's time to write the file, then we're done:

  ```elixir
  iex> BufEdit.save(buf)
  ```
  """

  @type t :: %__MODULE__{
          filename: String.t(),
          lines: [String.t()],
          line_num: integer(),
          col: integer(),
          status: :ok | :not_found
        }

  defstruct filename: nil,
            lines: [],
            line_num: 1,
            col: 1,
            status: :ok

  @doc "Load the file into the buffer"
  @spec load(filename :: String.t()) :: t()
  def load(filename) do
    contents = File.read!(filename)
    lines = String.split(contents, ~r/\r\n|\n/)

    %__MODULE__{
      filename: filename,
      lines: lines
    }
  end

  @doc "Dump the BufEdit to a string"
  @spec dump(t()) :: String.t()
  def dump(buf) do
    Enum.join(buf.lines, "\n")
  end

  @doc "Save the BufEdit to a file specified by the `:filename` value."
  @spec save(t()) :: :ok | no_return()
  def save(buf) do
    File.write!(buf.filename, dump(buf))
  end

  @doc "Get the current line."
  @spec line(t()) :: String.t()
  def line(buf) do
    Enum.at(buf.lines, buf.line_num - 1)
  end

  @doc "Get a list of lines starting from the current line number."
  @spec lines(buf :: t(), length :: integer()) :: [String.t()]
  def lines(buf, length) do
    0..(length - 1)
    |> Enum.map(fn i ->
      Enum.at(buf.lines, buf.line_num - 1 + i)
    end)
  end

  @doc "Search for a line using a regular expression."
  @spec search(buf :: t(), pattern :: Regex.t(), direction :: :down | :up) :: t()
  def search(buf, pattern, direction \\ :down) do
    line_with_index = matching_line_with_index(buf, pattern, direction)

    case line_with_index do
      {_line, index} ->
        buf = move_to(buf, index + 1, buf.col)
        %{buf | status: :ok}

      _ ->
        %{buf | status: :not_found}
    end
  end

  @doc "Insert a line at the current line number."
  @spec insert_line(buf :: t(), line :: String.t()) :: t()
  def insert_line(%{status: :ok} = buf, line) do
    lines = List.insert_at(buf.lines, buf.line_num - 1, line)

    buf
    |> set(:lines, lines)
    |> move_relative(1, buf.col)
    |> set(:status, :ok)
  end

  # Skip operation if :status != :ok
  def insert_line(buf, _line) do
    buf
  end

  @doc "Insert multiple lines at the current line number."
  @spec insert_lines(buf :: t(), lines :: [String.t()]) :: t()
  def insert_lines(buf, lines) do
    new_buf =
      lines
      |> Enum.reduce(buf, fn line, buf ->
        insert_line(buf, line)
      end)

    %{new_buf | status: :ok}
  end

  @doc "Move to the given line number and column"
  @spec move_to(buf :: t(), line_num :: integer(), col :: integer()) :: t()
  def move_to(buf, line_num, col) do
    %{buf | line_num: line_num, col: col, status: :ok}
  end

  @doc "Move to a line offset from the current line."
  @spec move_relative(buf :: t(), line_num_offset :: integer(), col_offset :: integer()) :: t()
  def move_relative(buf, line_num_offset, col_offset) do
    move_to(buf, buf.line_num + line_num_offset, buf.col + col_offset)
  end

  @doc "Move to the last line in the file."
  @spec move_to_end(buf :: t()) :: t()
  def move_to_end(buf) do
    count = length(buf.lines)
    move_to(buf, count, buf.col)
  end

  @doc "Delete a number of lines from the current line number"
  @spec delete_lines(buf :: t(), count :: integer()) :: t()
  def delete_lines(buf, count) do
    1..count
    |> Enum.reduce(buf, fn _n, buf ->
      delete_line(buf)
    end)
  end

  @doc "Delete the current line"
  @spec delete_line(buf :: t()) :: t()
  def delete_line(%{status: :ok} = buf) do
    lines = List.delete_at(buf.lines, buf.line_num - 1)
    %{buf | lines: lines, status: :ok}
  end

  # Skip operation if :status != :ok
  def delete_line(buf) do
    buf
  end

  @doc "Replace a sub string within the current line matching pattern."
  @spec replace_in_line(buf :: t(), search :: String.t(), replace :: String.t()) :: t()
  def replace_in_line(buf, search, replace) do
    replace_line(buf, fn _buf, line ->
      String.replace(line, search, replace)
    end)
  end

  @doc """
  Replace the current line with the output of a function.

  Example:

  Commenting out a line of Elixir:

  ```
  iex> BufEdit.replace_line(buf, fn _buf, line -> "# \#{line}" end)
  ```
  """
  @spec replace_line(t(), (t(), line :: String.t() -> String.t())) :: t()
  def replace_line(%{status: :ok} = buf, fun) do
    line = line(buf)
    buf = delete_line(buf)
    new_line = fun.(buf, line)
    insert_line(buf, new_line)
  end

  # Skip operation if :status != :ok
  def replace_line(buf, _fun) do
    buf
  end

  ## PRIVATE FUNCTIONS

  defp set(buf, key, value) do
    struct(buf, %{key => value})
  end

  defp matching_line_with_index(buf, pattern, direction) do
    lines =
      case direction do
        :down -> buf.lines
        :up -> Enum.reverse(buf.lines)
      end

    line_count = length(buf.lines)

    lines
    |> Enum.with_index()
    |> Enum.map(fn {line, index} ->
      case direction do
        :down -> {line, index}
        :up -> {line, line_count - index - 1}
      end
    end)
    |> Enum.filter(fn {_line, index} ->
      at_line_num = index + 1

      case direction do
        :down -> at_line_num >= buf.line_num
        :up -> at_line_num <= buf.line_num
      end
    end)
    |> Enum.find(fn {line, _index} ->
      String.match?(line, pattern)
    end)
  end
end
