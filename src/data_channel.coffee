Deferred = require('es6-deferred')


class exports.DataChannel

  constructor: (@channel) ->
    # buffer management

    @send_buffer = []
    @max_buffer = 1024 * 10

    # event handling

    @channel.onmessage = (event) =>
      @emit('message', event.data)

    @channel.onclose = () =>
      @emit('close')

    @channel.onerror = (err) =>
      @emit('error', err)


  label: () ->
    return @channel.label


  send: (data) ->
    defer = new Deferred()
    @send_buffer.push([data, defer])

    if @send_buffer.length == 1
      @_actualSend()

    return defer.promise


  _actualSend: () ->
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
        setTimeout(@_actualSend.bind(@), 1)

      defer.resolve()

      @send_buffer.shift()
