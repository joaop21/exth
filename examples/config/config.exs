import Config

# rpc_url is a runtime config defined in runtime.exs
config :examples, Examples.Provider.Ethereum, transport_type: :http

import_config "#{config_env()}.exs"
