Promise = require('./compat').compat.Promise
Peer = require('./peer').Peer

StreamCollection = require('./internal/stream_collection').StreamCollection
ChannelCollection = require('./internal/channel_collection').ChannelCollection


###*
# Represents a remote user of the room
# @class rtc.RemotePeer
# @extends rtc.Peer
#
# @constructor
# @param {rtc.PeerConnection} peer_connection The underlying peer connection
# @param {rtc.Signaling} signaling The signaling connection to the peer
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
  # @param {Promise -> rtc.Stream} stream Promise of the channel
  ###

  constructor: (@peer_connection, @signaling, @local, @options) ->
    # create streams

    @stream_collection = new StreamCollection()
    @streams = @stream_collection.streams
    @streams_desc = {}

    @stream_collection.on 'stream_added', (name, stream) ->
      @emit('stream_added', name, stream)

    # channels stuff

    @channel_collection = new ChannelCollection()
    @channels = @channel_collection.channels
    @channels_desc = {}

    @channel_collection.on 'data_channel_added', (name, channel) ->
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

    @signaling.on 'closed', () =>
      @peer_connection.close()
      @emit('left')

    # pass on signals

    @peer_connection.on 'connected', () =>

    @peer_connection.on 'closed', () =>
      # TODO

    # we probably want to connect now

    if not @options.auto_connect? or not @options.auto_connect
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

      for name, stream of @local.streams
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

        for name, options of @local.channels
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
  # Get a data channel to the remote peer. Has to be added by local and remote side to succeed.
  # @method channel
  # @param {String} [name='data'] Name of the data channel
  # @return {Promise -> rtc.DataChannel} Promise of the data channel
  ###
  channel: (name=@DEFAULT_CHANNEL) ->
    @channel_collection.get(name)
