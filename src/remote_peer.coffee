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

    # prepare streams

    # TODO

    # prepare data channels

    # TODO


  status: (key) ->
    if key?
      return @status_obj[key]
    else
      return @status_obj


  message: (data) ->
    @signaling.send('message', data)


  connect: () ->
    return @peer_connection.connect()


  close: () ->
    @peer_connection.close()
