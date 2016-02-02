{Deferred,Promise} = require('./internal/promise')
EventEmitter = require('events').EventEmitter

###*
# @module rtc
###
###*
# A wrapper for RTCDataChannel. Used to transfer custom data between peers.
# @class rtc.DataChannel
#
# @constructor
# @param {RTCDataChannel} channel The wrapped native data channel
# @param {Number} [max_buffer] The size of the send buffer after which we will delay sending
###
class exports.DataChannel extends EventEmitter

  ###*
  # A new messages was received. Triggers only after `connect()` was called
  # @event message
  # @param {ArrayBuffer} data The data received
  ###

  ###*
  # The channel was closed
  # @event closed
  ###

  constructor: (@channel, @max_buffer=1024*10) ->
    @_connected = false
    @_connect_queue = []

    # buffer management

    @_send_buffer = []

    # make sure we are using arraybuffer

    @channel.binaryType = 'arraybuffer'

    # event handling

    @channel.onmessage = (event) =>
      if not @_connected
        @_connect_queue.push(event.data)
      else
        @emit('message', event.data)

    @channel.onclose = () =>
      @emit('closed')

    # TODO: what to do with this?
    @channel.onerror = (err) =>
      @emit('error', err)


  ###*
  # Connect to the DataChannel. You will receive messages and will be able to send after calling this.
  # @method connect
  # @return {Promise} Promise which resolves as soon as the DataChannel is open
  ###
  connect: () ->
    @_connected = true

    for data in @_connect_queue
      @emit('message', data)

    delete @_connect_queue

    return Promise.resolve()


  close: () ->
    @channel.close()
    return Promise.resolve()


  ###*
  # The label of the DataChannel used to distinguish multiple channels
  # @method label
  # @return {String} The label
  ###
  label: () ->
    return @channel.label


  ###*
  # Send data to the peer through the DataChannel
  # @method send
  # @param data The data to be transferred
  # @return {Promise} Promise which will be resolved when the data was passed to the native data channel
  ####
  send: (data) ->
    if not @_connected
      @connect()
      console.log("Sending without being connected. Please call connect() on the data channel to start using it.")

    defer = new Deferred()
    @_send_buffer.push([data, defer])

    if @_send_buffer.length == 1
      @_actualSend()

    return defer.promise


  ###*
  # Method which actually sends the data. Implements buffering
  # @method _actualSend
  # @private
  ###
  _actualSend: () ->
    if @channel.readyState == 'open'
      # actual sending
      # TODO: help user with max package size?
      while @_send_buffer.length
        # should we keep sending right now?
        if @channel.bufferedAmount >= @max_buffer
          # TODO: less cpu heavy timeout value?
          setTimeout(@_actualSend.bind(@), 1)
          return

        [data, defer] = @_send_buffer[0]

        try
          @channel.send(data)
        catch
          # TODO: less cpu heavy and fail after some time?
          # TODO: do not loop endless on fatal errors which do not close the channel
          setTimeout(@_actualSend.bind(@), 1)
          return

        defer.resolve()

        @_send_buffer.shift()

    else
      # fail the send promises
      while @_send_buffer.length
        [data, defer] = @_send_buffer.shift()
        defer.reject(new Error("DataChannel closed"))
