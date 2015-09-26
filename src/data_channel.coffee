Deferred = require('es6-deferred')
EventEmitter = require('events').EventEmitter


class exports.DataChannel extends EventEmitter

  constructor: (@channel) ->
    @connected = false
    @connect_queue = []

    # buffer management

    @send_buffer = []
    @max_buffer = 1024 * 10

    # event handling

    @channel.onmessage = (event) =>
      if not @connected
        @connect_queue.push(event.data)
      else
        @emit('message', event.data)

    @channel.onclose = () =>
      @emit('close')

    @channel.onerror = (err) =>
      @emit('error', err)


  connect: () ->
    @connected = true

    for data in @connect_queue
      @emit('message', data)

    delete @connect_queue

    return Promise.resolve()


  label: () ->
    return @channel.label


  send: (data) ->
    if not @connected
      @connect()
      console.log("Sending without being connected. Please call connect() on the data channel to start using it.")

    defer = new Deferred()
    @send_buffer.push([data, defer])

    if @send_buffer.length == 1
      @_actualSend()

    return defer.promise


  _actualSend: () ->
    if @channel.readyState == 'open'
      # actual sending
      # TODO: help user with max package size?
      while @send_buffer.length
        # should we keep sending right now?
        if @channel.bufferedAmount >= @max_buffer
          # TODO: less cpu heavy timeout value?
          setTimeout(@_actualSend.bind(@), 1)
          return

        [data, defer] = @send_buffer[0]

        try
          @channel.send(data)
        catch
          # TODO: less cpu heavy and fail after some time?
          # TODO: do not loop endless on fatal errors which do not close the channel
          setTimeout(@_actualSend.bind(@), 1)
          return

        defer.resolve()

        @send_buffer.shift()

    else
      # fail the send promises
      while @send_buffer.length
        [data, defer] = @send_buffer.shift()
        defer.reject(new Error("DataChannel closed"))
