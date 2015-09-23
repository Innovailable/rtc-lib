q = require('q')

EventEmitter = require('events').EventEmitter


class PalavaSignalingPeer extends EventEmitter

  constructor: (@channel, @id, @status, @first) ->
    @streams = @status.streams
    @channels = @status.channels

    @channel.on 'message', (data) =>
      if data.sender_id != @id
        # message is not for us
        return

      if not data.event?
        @send('error', "Invalid message")
        return

      @emit(data.event, data.data)

    @on 'peer_updated_status', (status) =>
      @emit('update_status', status)
      @emit('update_streams', status.streams)

    @on 'peer_left', () =>
      @emit('closed')


  send: (event, data={}) ->
    return @channel.send({
      event: 'send_to_peer'
      peer_id: @id
      data:
        event: event
        data: data
    })


class exports.PalavaSignaling extends EventEmitter

  constructor: (@channel) ->
    @peers = {}
    @joined = false

    join_d = q.defer()
    @join_p = join_d.promise

    @channel.on 'message', (data) =>
      if not data.event?
        # invalid message
        return

      switch data.event
        when 'joined_room'
          if not data.peers? or not data.own_id?
            # invalid ...
            return

          for i, data of data.peers
            peer = new PalavaSignalingPeer(@channel, data.peer_id, data.status, false)
            @peers[data.peer_id] = peer
            @emit('peer_joined', peer)

          join_d.resolve()

        when 'new_peer'
          if not data.peer_id?
            # invalid ...
            return

          peer = new PalavaSignalingPeer(@channel, data.peer_id, data.status, true)
          @peers[data.peer] = peer
          @emit('peer_joined', peer)


  join: (room, status, streams, channels) ->
    if @joined
      return Q.reject(new Error("Joined already"))

    @joined = true

    status.streams = streams
    status.channels = channels

    return @channel.send({
      event: 'join_room'
      room_id: room
      status: status
    }).then () =>
      return @join_p


  set_status: (status) ->
    return @channel.send({
      event: 'update_status'
      status: status
    })


  set_streams: (streams) ->
    return @channel.send({
      event: 'update_status'
      status: {streams: streams}
    })


  leave: () ->
    @channel.close()
