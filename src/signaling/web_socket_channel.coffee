{Promise} = require('../internal/promise')
EventEmitter = require('events').EventEmitter


###*
# @module rtc.signaling
# @class rtc.signaling.WebSocketChannel
###
class exports.WebSocketChannel extends EventEmitter

  constructor: (@address) ->


  connect: () ->
    if not @connect_p?
      @connect_p = new Promise (resolve, reject) =>
        socket = new WebSocket(@address)

        socket.onopen = () =>
          @socket = socket
          resolve()

        socket.onerror = (err) =>
          # TODO: better error handling
          # TODO: handle errors after connecting
          delete @socket
          @emit('error', err)
          reject(new Error("Unable to connect to socket"))

        socket.onmessage = (event) =>
          try
            data = JSON.parse(event.data)
          catch
            @emit('error', "Unable to parse incoming message")
            return

          @emit('message', data)

        socket.onclose = () =>
          @emit 'close'

    return @connect_p


  send: (msg) ->
    if @socket?
      # TODO: maybe do fancy buffer handling like DataChannel
      try
        @socket.send(JSON.stringify(msg))
        return Promise.resolve()
      catch err
        return Promise.reject(err)
    else
      Promise.reject(new Error("Trying to send on WebSocket without being connected"))


  close: () ->
    if @socket?
      try
        @socket.close()
        return Promise.resolve()
      catch err
        return Promise.reject(err)
    else
      Promise.reject(new Error("Trying to close WebSocket without being connected"))
