EventEmitter = require('events').EventEmitter


class PalavaSignalingPeer extends EventEmitter

  constructor: (@channel, @peer_id, @status) ->
    @channel.on 'message', (data) =>
      if data.sender_id == @peer_id
        # message is not for us
        return

      if not data.event?
        @send('error', "Invalid message")
        return


  send: (event, data={}) ->
    return @channel.send({
      event: 'send_to_peer'
      peer_id: @peer_id
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

      switch data.type
        when 'joined_room'
          if not data.peers? or not data.own_id?
            # invalid ...
            return

          for peer_id, status of data.peers
            peer = new SignalingPeer(@channel, peer_id, status)
            @peers[peer_id] = peer
            @emit('peer_joined', peer)

          join_d.resolve()

        when 'new_peer'
          if not data.peer_id?
            # invalid ...
            return

          peer = new SignalingPeer(@channel, data.peer_id, data.status)
          @peers[data.peer] = peer
          @emit('peer_joined', peer)


  join: (room, status={}) ->
    if @joined
      return Q.reject(new Error("Joined already"))

    @joined = true

    return @channel.send({
      event: 'join_room'
      room_id: room
      status: status
    }).then () ->
      return @join_p


  set_status: (status) ->
    return @channel.send({
      event: 'update_status'
      status: status
    })


  leave: () ->
    @channel.close()
