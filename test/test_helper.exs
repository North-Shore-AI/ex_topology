ExUnit.start()

# Configure ExUnit
ExUnit.configure(
  exclude: [:cross_validation, :slow],
  formatters: [ExUnit.CLIFormatter]
)
