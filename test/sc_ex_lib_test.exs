defmodule ScExLibTest do
  use ExUnit.Case
  doctest ScExLib

  test "greets the world" do
    assert ScExLib.hello() == :world
  end
end
