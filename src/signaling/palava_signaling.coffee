{Deferred} = require('../internal/promise')
{Signaling,SignalingPeer} = require('./signaling')


###*
# @module rtc.signaling
###

###*
# Signaling peer compatible with the framing of palava signaling
# @class rtc.signaling.PalavaSignalingPeer
# @extends rtc.signaling.SignalingPeer
###
class exports.PalavaSignalingPeer extends SignalingPeer

  constructor: (@channel, @id, @status, @first) ->
    recv_msg = (data) =>
      if data.sender_id != @id
        # message is not for us
        return

      if not data.event?
        @send('error', "Invalid message")
        return

      @emit(data.event, data.data)

    @channel.on('message', recv_msg)

    @on 'peer_updated_status', (status) =>
      @emit('new_status', status)

    @on 'peer_left', () =>
      @emit('closed')
      @channel.removeListener('message', recv_msg)


  send: (event, data={}) ->
    return @channel.send({
      event: 'send_to_peer'
      peer_id: @id
      data:
        event: event
        data: data
    })


###*
# Signaling implementation compatible with the framing of palava signaling
# @class rtc.signaling.PalavaSignaling
# @extends rtc.signaling.Signaling
###
class exports.PalavaSignaling extends Signaling

  constructor: (@channel, @room, @status) ->
    @peers = {}
    @joined = false

    join_d = new Deferred()
    @join_p = join_d.promise

    @channel.on 'closed', () =>
      @emit('closed')

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
            peer = new exports.PalavaSignalingPeer(@channel, data.peer_id, data.status, false)
            @peers[data.peer_id] = peer
            @emit('peer_joined', peer)

          join_d.resolve()

        when 'new_peer'
          if not data.peer_id?
            # invalid ...
            return

          peer = new exports.PalavaSignalingPeer(@channel, data.peer_id, data.status, true)
          @peers[data.peer] = peer
          @emit('peer_joined', peer)


  connect: () ->
    if not @connect_p?
      @connect_p = @channel.connect().then () =>
        return @channel.send({
          event: 'join_room'
          room_id: room
          status: status
        })

    return @connect_p


  set_status: (status) ->
    return @channel.send({
      event: 'update_status'
      status: status
    })


  leave: () ->
    @channel.close()
