defmodule BufferTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Buffer

  test "search :down" do
    buf = load("test/fixtures/test.txt")
    result = search(buf, ~r/Wally/, :down)
    assert result.status == :ok
    assert result.line_num == 3
    assert line(result) == "Wally"
  end

  test "search :up" do
    buf = load("test/fixtures/test.txt")
    buf = move_to(buf, 5, 0)
    result = search(buf, ~r/Wally/, :up)
    assert result.status == :ok
    assert result.line_num == 3
    assert line(result) == "Wally"
  end

  test "insert_line/2" do
    buf = load("test/fixtures/test.txt")
    buf = move_to(buf, 2, 0)
    result = insert_line(buf, "New line 2")
    assert result.status == :ok
    [_, new_line | _] = result.lines
    assert new_line == "New line 2"
    assert length(result.lines) == length(buf.lines) + 1
    assert result.line_num == buf.line_num + 1
  end

  test "insert_lines/2" do
    buf = load("test/fixtures/test.txt")
    buf = move_to(buf, 2, 0)
    result = insert_lines(buf, ["New line 2", "New line 3"])
    assert result.status == :ok

    assert result.lines == [
             "Test file",
             "New line 2",
             "New line 3",
             "",
             "Wally",
             "line 4",
             "line 5",
             "line 6",
             ""
           ]

    current_line = line(result)
    assert current_line == ""
    assert result.line_num == 4

    result = insert_lines(result, ["Another line"])

    assert result.lines == [
             "Test file",
             "New line 2",
             "New line 3",
             "Another line",
             "",
             "Wally",
             "line 4",
             "line 5",
             "line 6",
             ""
           ]
  end

  test "delete_line/1 with :ok status" do
    buf =
      load("test/fixtures/test.txt")
      |> search(~r/Wally/)
      |> delete_line()

    assert buf.lines == ["Test file", "", "line 4", "line 5", "line 6", ""]
  end

  test "delete_line/1 with not-:ok status" do
    buf =
      load("test/fixtures/test.txt")
      |> search(~r/Not here/)
      |> delete_line()

    assert buf.lines == ["Test file", "", "Wally", "line 4", "line 5", "line 6", ""]
  end
end
