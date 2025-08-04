Code.require_file("support/test_helpers.exs", __DIR__)

Mimic.copy(Exth.Rpc.MessageHandler)
Mimic.copy(Exth.Transport)
Mimic.copy(Exth.Transport.Ipc.ConnectionPool)
Mimic.copy(Exth.Transport.Ipc.Socket)
Mimic.copy(Exth.Transport.Websocket)
Mimic.copy(Exth.Transport.Websocket.DynamicSupervisor)

Mimic.copy(Fresh)

ExUnit.start()
