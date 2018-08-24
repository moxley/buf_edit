defmodule BufEdit.MixProject do
  use Mix.Project

  def project do
    [
      app: :buffer,
      name: "BufEdit",
      description: "A line editor for Elixir, similar in concept to ed",
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/moxley/buf_edit"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Moxley Stratton"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/moxley/buf_edit"}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "BufEdit",
      extras: ["README.md"]
    ]
  end
end
