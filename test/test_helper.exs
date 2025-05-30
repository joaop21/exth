Code.require_file("support/test_helpers.exs", __DIR__)

Mimic.copy(Fresh)
Mimic.copy(Exth.Transport)
Mimic.copy(Exth.Transport.Websocket)

ExUnit.start()
