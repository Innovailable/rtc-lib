{Promise} = require('../internal/promise')
{Channel} = require('./signaling')

###*
# @module rtc.signaling
###
###*
# @class rtc.signaling.WebSocketChannel
# @extends rtc.signaling.Channel
###
class exports.WebSocketChannel extends Channel

  constructor: (@address, parts...) ->
    if parts.length > 0
      # remove trailing slashes
      while @address.endsWith('/')
        @address = @address.substr(0, @address.length - 1)

      # add parts
      for part in parts
        @address += '/' + encodeUriComponent(part)


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
          reject(new Error("Unable to connect to socket"))

        socket.onmessage = (event) =>
          try
            data = JSON.parse(event.data)
          catch
            return

          @emit('message', data)

        socket.onclose = () =>
          @emit 'closed'

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
