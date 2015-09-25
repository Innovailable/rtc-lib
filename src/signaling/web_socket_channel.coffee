Deferred = require('es6-deferred')
EventEmitter = require('events').EventEmitter
Promise = require('../compat').compat.Promise


class exports.WebSocketChannel extends EventEmitter

  constructor: (@address) ->


  connect: () ->
    if not @connect_p?
      @connect_p = new Promise (resolve, reject) =>
        @socket = new WebSocket(@address)

        @socket.onopen = () =>
          resolve()

        @socket.onerror = (err) =>
          # TODO: better error handling
          # TODO: handle errors after connecting
          reject(new Error("Unable to connect to socket"))

        @socket.onmessage = (event) =>
          try
            data = JSON.parse(event.data)
          catch
            @emit('error', "Unable to parse incoming message")
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
