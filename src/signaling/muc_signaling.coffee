{Deferred} = require('../internal/promise')
{Signaling,SignalingPeer} = require('./signaling')
EventEmitter = require('events').EventEmitter

###*
# @module rtc.signaling
###

###*
# Signaling peer for multi user chats.
#
# For a detailed description of the signaling protocol see `rtc.signaling.MucSignaling`
#
# @extends rtc.signaling.SignalingPeer
# @class rtc.signaling.MucSignalingPeer
#
# @constructor
# @param {rtc.signaling.Channel} channel The channel to the siganling server
# @param {String} peer_id The id of the remote peer
# @param {Object} status The status of the remote peer
# @param {Boolean} first Whether the local peer was in the room before the remote peer
###
class exports.MucSignalingPeer extends SignalingPeer

  constructor: (@channel, @peer_id, @status, @first) ->
    recv_msg = (data) =>
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
          @channel.removeListener('message', recv_msg)

        when 'peer_status'
          @status = data.status
          @emit('status_changed', @status)

    @channel.on('message', recv_msg)


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
#     // join the room. has to be sent before any other message.
#     // response will be 'joined' on success
#     // other peers in the room will get 'peer_joined'
#     {
#       "type": "join",
#       "status": { .. status .. }
#     }
#
#     // leave the room. server will close the connectino.
#     {
#       "type": "leave"
#     }
#
#     // update status object
#     // other peers will get 'peer_status'
#     {
#       "type": "status",
#       "status": { .. status .. }
#     }
#
#     // send message to a peer. will be received as 'to'
#     {
#       "type": "to",
#       "peer": "peer_id",
#       "event": "event_id",
#       "data": { .. custom data .. }
#     }
#
# The following messages are received form the server:
#
#     // joined the room. is the response to 'join'
#     {
#       "type": "joined",
#       "peers": {
#         "peer_id": { .. status .. }
#       }
#     }
#
#     // another peer joined the room.
#     {
#       "type": "peer_joined",
#       "peer": "peer_id",
#       "status": { .. status .. }
#     }
#
#     // anosther peer updated its status object using 'status'
#     {
#       "type": "peer_status",
#       "peer": "peer_id",
#       "status": { .. status .. }
#     }
#
#     // another peer left the room
#     {
#       "type": "peer_left",
#       "peer": "peer_id"
#     }
#
#     // message from another peer sent by 'to'
#     {
#       "type": "from",
#       "peer": "peer_id",
#       "event": "event_id",
#       "data": { .. custom data .. }
#     }
#
# The messages transmitted in the `to`/`from` messages are emitted as events in `MucSignalingPeer`
#
# @extends rtc.signaling.Signaling
# @class rtc.signaling.MucSignaling
#
# @constructor
# @param {rtc.signaling.Channel} channel The channel to the signaling server
###
class exports.MucSignaling extends Signaling

  constructor: (@channel) ->
    @status = {}

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
