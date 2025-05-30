Code.require_file("support/test_helpers.exs", __DIR__)

Mimic.copy(Exth.Rpc.MessageHandler)
Mimic.copy(Exth.Transport)
Mimic.copy(Exth.Transport.Websocket)

Mimic.copy(Fresh)

ExUnit.start()
