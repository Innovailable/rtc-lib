Deferred = require('es6-deferred')
EventEmitter = require('events').EventEmitter


class exports.WebSocketChannel extends EventEmitter

  constructor: (@address) ->


  connect: () ->
    if @socket?
      return @connect_p

    @socket = new WebSocket(@address)

    connect_d = new Deferred()
    @connect_p = connect_d.promise

    @socket.onopen = () =>
      connect_d.resolve()

    @socket.onerror = (err) =>
      # TODO: better error handling
      # TODO: handle errors after connecting
      connect_d.reject(err)

    @socket.onmessage = (event) =>
      try
        data = JSON.parse(event.data)
      catch
        console.log('error parsing incoming message')
        return

      @emit('message', data)

    @socket.onclose = () =>
      @emit 'close'

    return @connect_p


  send: (msg) ->
    return @connect().then () =>
      return @socket.send(JSON.stringify(msg))


  close: () ->
    return @connect().then () =>
      @socket.close()
