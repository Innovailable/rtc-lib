rtc = require('./lib')

class RemotePeer

  constructor: (@status_obj, @direct_channel, @peer_connection, @local) ->
    # communication

    @direct_channel.on 'message', (data) =>
      @emit 'message', data

    @direct_channel.on 'peer_update_status', (status) =>
      @status_obj = status
      @emit 'status_changed', status

    @direct_channel.on 'peer_left', () =>
      @close()
      @emit 'left'

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
    @direct_channel.send('message', data)


  connect: () ->
    return @pc.connect()


  close: () ->
    @pc.close()
    @emit 'closed'


exports.RemotePeer = RemotePeer
