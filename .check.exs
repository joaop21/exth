[
  parallel: true,
  skipped: true,
  fix: false,
  retry: false,
  tools: [
    {:compiler, "mix compile --warnings-as-errors"},
    {:dialyzer, "mix dialyzer --format github --format dialyxir"},
  ]
]
