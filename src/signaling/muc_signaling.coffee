Deferred = require('es6-deferred')
EventEmitter = require('events').EventEmitter


class MucSignalingPeer extends EventEmitter

  constructor: (@channel, @peer_id, @status) ->
    @channel.on 'message', (data) =>
      if data.peer == @peer_id
        # message is not for us
        return

      if not data.type?
        @send('error', "Invalid message")
        return

      switch data.type
        when 'event'
          if not data.event? or not data.data?
            @send('error', "Invalid event message")
            return

          @emit(data.event, data.data)

        when 'peer_left'
          @emit('left')

        when 'updated_status'
          @status = data.status
          @emit 'updated_status', @status

        else
          @send('error', "Unable to process message")


  send: (event, data={}) ->
    return @channel.send({
      type: 'event'
      peer: @peer_id
      event: event
      data: data
    })


class exports.MucSignaling extends EventEmitter

  constructor: (@channel) ->
    @peers = {}
    @joined = false

    join_d = new Deferred()
    @join_p = join_d.promise

    @channel.on 'message', (data) =>
      if not data.type?
        # invalid message
        return

      switch data.type
        when 'joined_room'
          if not data.peers? or not data.self?
            # invalid ...
            return

          for peer_id, status of data.peers
            peer = new SignalingPeer(@channel, peer_id, status)
            @peers[peer_id] = peer
            @emit('peer_joined', peer)

          join_d.resolve()

        when 'peer_joined'
          if not data.peer?
            # invalid ...
            return

          peer = new SignalingPeer(@channel, data.peer, data.status)
          @peers[data.peer] = peer
          @emit('peer_joined', peer)


  join: (room, status={}) ->
    if @joined
      return Q.reject(new Error("Joined already"))

    @joined = true

    return @channel.send({
      type: 'join_room'
      room: room
      status: status
    }).then () ->
      return @join_p


  set_status: (status) ->
    return @channel.send({
      type: 'update_status'
      status: status
    })


  leave: () ->
    @channel.send({
      type: 'leave_room'
    }).then () ->
      @channel.close()
