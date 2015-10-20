{Promise} = require('./internal/promise')
Peer = require('./peer').Peer

StreamCollection = require('./internal/stream_collection').StreamCollection
ChannelCollection = require('./internal/channel_collection').ChannelCollection

merge = () ->
  # WARNING: later occurences of the same key will overwrite
  res = {}

  for array in arguments
    for key, value of array
      res[key] = value

  return res


###*
# @module rtc
###
###*
# Represents a remote user of the room
# @class rtc.RemotePeer
# @extends rtc.Peer
#
# @constructor
# @param {rtc.PeerConnection} peer_connection The underlying peer connection
# @param {rtc.SignalingPeer} signaling The signaling connection to the peer
# @param {rtc.LocalPeer} local The local peer
# @param {Object} options The options object as passed to `Room`
###
class exports.RemotePeer extends Peer

  ###*
  # Message received from peer through signaling
  # @event message
  # @param data The payload of the message
  ###

  ###*
  # The remote peer left or signaling closed
  # @event left
  ###

  ###*
  # A new stream is available from the peer
  # @event stream_added
  # @param {String} name Name of the stream
  # @param {Promise -> rtc.Stream} stream Promise of the stream
  ###

  ###*
  # A new data channel is available from the peer
  # @event data_channel_added
  # @param {String} name Name of the channel
  # @param {Promise -> rtc.DataChannel} channel Promise of the channel
  ###

  constructor: (@peer_connection, @signaling, @local, @options) ->
    # create streams

    @private_streams = {}
    @private_channels = {}

    @stream_collection = new StreamCollection()
    @streams = @stream_collection.streams
    @streams_desc = {}

    @stream_collection.on 'stream_added', (name, stream) =>
      @emit('stream_added', name, stream)

    # channels stuff

    @channel_collection = new ChannelCollection()
    @channels = @channel_collection.channels
    @channels_desc = {}

    @channel_collection.on 'data_channel_added', (name, channel) =>
      @emit('data_channel_added', name, channel)

    # resolve streams and data channels

    @peer_connection.on 'stream_added', (stream) =>
      @stream_collection.resolve(stream)

    @peer_connection.on 'data_channel_ready', (channel) =>
      @channel_collection.resolve(channel)

    # wire up peer connection signaling

    @peer_connection.on 'signaling', (data) =>
      data.streams = @streams_desc
      data.channels = @channels_desc
      @signaling.send('signaling', data)

    @signaling.on 'signaling', (data) =>
      @stream_collection.update(data.streams)
      @channel_collection.setRemote(data.channels)
      @peer_connection.signaling(data)

    @peer_connection.on 'ice_candidate', (candidate) =>
      @signaling.send('ice_candidate', candidate)

    @signaling.on 'ice_candidate', (candidate) =>
      @peer_connection.addIceCandidate(candidate)

    # status handling
 
    @signaling.on 'status_changed', (key, value) =>
      @emit('status_changed', key, value)

    # communication

    @signaling.on 'message', (data) =>
      @emit('message', data)

    @signaling.on 'left', () =>
      @peer_connection.close()
      @emit('left')

    # pass on signals

    @peer_connection.on 'connected', () =>

    @peer_connection.on 'closed', () =>
      # TODO

    # we probably want to connect now

    if not @options.auto_connect? or @options.auto_connect
      @connect()


  # documented in Peer
  status: (key) ->
    @signaling.status[key]


  ###*
  # Send a message to the peer through signaling
  # @method message
  # @param data The payload
  # @return {Promise} Promise which is resolved when the data was sent
  ###
  message: (data) ->
    return @signaling.send('message', data)


  ###*
  # Connect to the remote peer to exchange streams and create data channels
  # @method connect
  # @return {Promise} Promise which will resolved when the connection is established
  ###
  connect: () ->
    if not @connect_p?
      # wait for streams

      stream_promises = []

      for name, stream of merge(@local.streams, @private_streams)
        promise = stream.then (stream) ->
          return [name, stream]

        stream_promises.push(promise)

      # TODO: really fail on failed streams?
      @connect_p = Promise.all(stream_promises).then (streams) =>
        # add all streams

        for [name, stream] in streams
          @peer_connection.addStream(stream)
          @streams_desc[name] = stream.id()

        # create data channels

        for name, options of merge(@local.channels, @private_channels)
          @peer_connection.addDataChannel(name, options)
          @channels_desc[name] = options

        @channel_collection.setLocal(@channels_desc)

        # actually connect

        return @peer_connection.connect()

    return @connect_p


  ###*
  # Closes the connection to the peer
  # @method close
  ###
  close: () ->
    @peer_connection.close()
    return


  ###*
  # Get a stream from the peer. Has to be sent by the remote peer to succeed.
  # @method stream
  # @param {String} [name='stream'] Name of the stream
  # @return {Promise -> rtc.Stream} Promise of the stream
  ###
  stream: (name=@DEFAULT_STREAM) ->
    @stream_collection.get(name)


  ###*
  # Add local stream to be sent to this remote peer
  #
  # If you use this method you have to set `auto_connect` to `false` in the options object and call `connect()` manually on all remote peers.
  #
  # @method addStream
  # @param {String} [name='stream'] Name of the stream
  # @param {Promise -> rtc.Stream | rtc.Stream | Object} stream The stream, a promise to the stream or the configuration to create a stream with `rtc.Stream.createStream()`
  # @return {Promise -> rtc.Stream} Promise of the stream which was added
  ###
  addStream: (name, obj) ->
    if not (@options.auto_connect == false)
      return Promise.reject("Unable to add streams directly to remote peers without 'auto_connect' option set to 'false'")

    # helper to actually save stream
    saveStream = (stream_p) =>
      # TODO: collision detection?
      @private_streams[name] = stream_p
      return stream_p

    # name can be omitted ... once
    if typeof name != 'string'
      obj = name
      name = @DEFAULT_STREAM

    if obj?.then?
      # it is a promise
      return saveStream(obj)
    else if obj instanceof Stream
      # it is the actual stream, turn into promise
      return saveStream(Promise.resolve(obj))
    else
      # we assume we can pass it on to create a stream
      stream_p = Stream.createStream(obj)
      return saveStream(stream_p)


  ###*
  # Get a data channel to the remote peer. Has to be added by local and remote side to succeed.
  # @method channel
  # @param {String} [name='data'] Name of the data channel
  # @return {Promise -> rtc.DataChannel} Promise of the data channel
  ###
  channel: (name=@DEFAULT_CHANNEL) ->
    @channel_collection.get(name)


  ###*
  # Add data channel which will be negotiated with this remote peer
  #
  # If you use this method you have to set `auto_connect` to `false` in the options object and call `connect()` manually on all remote peers.
  #
  # @method addDataChannel
  # @param {String} [name='data'] Name of the data channel
  # @param {Object} [desc={ordered: true}] Options passed to `RTCDataChannel.createDataChannel()`
  ###
  addDataChannel: (name, desc) ->
    if not (@options.auto_connect == false)
      return Promise.reject("Unable to add channels directly to remote peers without 'auto_connect' option set to 'false'")

    if typeof name != 'string'
      desc = name
      name = @DEFAULT_CHANNEL

    if not desc?
      # TODO: default handling
      desc = {
        ordered: true
      }

    @private_channels[name] = desc

    return @channel(name)
