q = require('q')

class exports.RemotePeer

  constructor: (@peer_connection, @signaling, @local) ->
    # communication

    @signaling.on 'message', (data) =>
      @emit 'message', data

    # pass on signals

    @peer_connection.on 'connected', () =>
      @emit 'connected'

    @peer_connection.on 'closed', () =>
      @emit 'closed'

    # prepare data channels

    # TODO


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
