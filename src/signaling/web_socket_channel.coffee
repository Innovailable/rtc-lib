q = require('q')
EventEmitter = require('events').EventEmitter


class WebSocketChannel extends EventEmitter

  constructor: (@address) ->


  connect: () ->
    if @socket?
      return @connect_p

    @socket = new WebSocket(@address)

    connect_d = q.defer()
    @connect_p = connect_d.promise

    @socket.onopen = () =>
      connect_d.resolve()

    @socket.onerror = (err) =>
      # TODO: better error handling
      # TODO: handle errors after connecting
      connect_d.reject(err)

    @socket.onmessage = (raw) =>
      try
        @emit 'message', JSON.parse(raw)
      catch SyntaxError
        # TODO: error handling ...

    @socket.onclose = () =>
      @emit 'close'

    return @connect_p


  send: (msg) ->
    return @connect().then () =>
      return @socket.send(msg)


  close: () ->
    return @connect().then () =>
      @socket.close()
