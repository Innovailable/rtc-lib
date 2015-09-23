q = require('q')

Peer = require('./peer').Peer
StreamCollection = require('./stream_collection.coffee').StreamCollection


class exports.RemotePeer extends Peer

  constructor: (@peer_connection, @signaling, @local, @options) ->
    # create streams

    stream_collection = new StreamCollection(@signaling.streams)
    @streams = stream_collection.streams

    # resolve streams

    @peer_connection.on 'stream_added', (stream) =>
      stream_collection.resolve(stream)

    # communication

    @signaling.on 'message', (data) =>
      @emit 'message', data

    # assign a name to a previously unnamed stream
    @signaling.on 'update_streams', (data) =>
      stream_collection.update(data)

    # pass on signals

    @peer_connection.on 'connected', () =>
      @emit 'connected'

    @peer_connection.on 'closed', () =>
      @emit 'closed'

    # prepare data channels

    # TODO

    # we probably want to connect now

    if not @options.auto_connect? or not @options.auto_connect
      @connect().done()


  status: (key) ->
    if key?
      return @status_obj[key]
    else
      return @status_obj


  message: (data) ->
    return @signaling.send('message', data)


  connect: () ->
    if not @connect_p
      stream_promises = []

      for name, stream of @local.streams
        stream_promises.push(stream)

      # TODO: really fail on failed streams?
      @connect_p = q.all(stream_promises).then (streams) =>
        for stream in streams
          @peer_connection.addStream(stream)

        return @peer_connection.connect()

    return @connect_p


  close: () ->
    return @peer_connection.close()
