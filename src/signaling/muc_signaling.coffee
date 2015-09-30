{Deferred} = require('../internal/promise')
EventEmitter = require('events').EventEmitter

###*
# Signaling peer for multi user chats.
#
# For a detailed description of the signaling protocol see `rtc.signaling.MucSignaling`
#
# @module rtc.signaling
# @class rtc.signaling.MucSignalingPeer
###
class exports.MucSignalingPeer extends EventEmitter

  constructor: (@channel, @peer_id, @status, @first) ->
    @channel.on 'message', (data) =>
      if data.peer != @peer_id
        # message is not for us
        return

      if not data.type?
        # invalid message
        return

      switch data.type
        when 'from'
          if not data.event? or not data.data?
            # invalid message
            return

          @emit(data.event, data.data)

        when 'peer_left'
          @emit('left')

        when 'peer_status'
          @status = data.status
          @emit('new_status', @status)


  send: (event, data={}) ->
    return @channel.send({
      type: 'to'
      peer: @peer_id
      event: event
      data: data
    })


###*
# Signaling for multi user chats
#
# The following messages are sent to the server:
#
#     // join the room
#     {
#       "type": "join",
#       "status": {}
#     }
#
#     // leave the room
#     {
#       "type": "leave"
#     }
#
#     // update status
#     {
#       "type": "status",
#       "status": {}
#     }
#
#     // send message to a peer
#     {
#       "type": "to",
#       "peer": "peer_id",
#       "data": { .. custom data .. }
#     }
#
# The following messages are received form the server:
#
#     // joined the room
#     {
#       "type": "joined",
#       "peers": {
#         "peer_id": { .. status .. }
#       }
#     }
#
#     // peer joined the room
#     {
#       "type": "peer_joined",
#       "peer": "peer_id",
#       "status": { .. status .. }
#     }
#
#     // peer updated its status
#     {
#       "type": "peer_status",
#       "peer": "peer_id",
#       "status": { .. status .. }
#     }
#
#     // peer left
#     {
#       "type": "peer_left",
#       "peer": "peer_id"
#     }
#
#     // message from peer
#     {
#       "type": "from",
#       "peer": "peer_id",
#       "event": "event_id",
#       "data": { .. custom data .. }
#     }
#
# The messages transmitted in the `to`/`from` messages are emitted as events in `MucSignalingPeer`
#
# @module rtc.signaling
# @class rtc.signaling.MucSignaling
###
class exports.MucSignaling extends EventEmitter

  constructor: (@channel, @status) ->
    join_d = new Deferred()
    @join_p = join_d.promise

    @channel.on 'closed', () =>
      @emit('closed')

    @channel.on 'message', (data) =>
      if not data.type?
        # invalid message
        return

      switch data.type
        when 'joined'
          if not data.peers?
            # invalid ...
            return

          for peer_id, status of data.peers
            peer = new exports.MucSignalingPeer(@channel, peer_id, status, false)
            @emit('peer_joined', peer)

          join_d.resolve()

        when 'peer_joined'
          if not data.peer?
            # invalid ...
            return

          peer = new exports.MucSignalingPeer(@channel, data.peer, data.status, true)
          @emit('peer_joined', peer)


  connect: () ->
    if not @connect_p?
      @connect_p = @channel.connect().then () =>
        return @channel.send({
          type: 'join'
          status: @status
        })
      .then () =>
        return @join_d

    return @connect_p


  setStatus: (status) ->
    @status = status

    if @connect_p
      @connect_p.then () ->
        return @channel.send({
          type: 'status'
          status: status
        })


  leave: () ->
    @channel.send({
      type: 'leave'
    }).then () ->
      @channel.close()
