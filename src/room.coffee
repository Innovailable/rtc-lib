EventEmitter = require('events').EventEmitter

{WebSocketChannel} = require('./signaling/web_socket_channel')
{MucSignaling} = require('./signaling/muc_signaling')

RemotePeer = require('./remote_peer').RemotePeer
LocalPeer = require('./local_peer').LocalPeer
PeerConnection = require('./peer_connection').PeerConnection

###*
# @module rtc
###
###*
# A virtual room which connects multiple Peers
# @class rtc.Room
#
# @constructor
# @param {String} name The name of the room. Will be passed on to signaling
# @param {rtc.Signaling | String} signaling The signaling to be used. If you pass a string it will be interpreted as a websocket address and a palava signaling connection will be established with it.
# @param {Object} [options] Various options to be used in connections created by this room
# @param {Boolean} [options.auto_connect=true] Whether remote peers are connected automatically or an explicit `RemotePeer.connect()` call is needed
# @param {String} [options.stun] The URI of the STUN server to use
# @param {rtc.LocalPeer} [options.local] The local user
###
class exports.Room extends EventEmitter

  ###*
  # A new peer is encountered in the room. Fires on new remote peers after joining and for all peers in the room when joining.
  # @event peer_jopined
  # @param {rtc.RemotePeer} peer The new peer
  ###

  ###*
  # A peer left the room.
  # @event peer_left
  # @param {rtc.RemotePeer} peer The peer which left
  ###

  ###*
  # A peer changed its status.
  # @event peer_status_changed
  # @param {rtc.RemotePeer} peer The peer which changed its status
  # @param {Object} status The new status
  ###

  ###*
  # The connection to the room was closed
  # @event closed
  ###

  ###*
  # The underlying signaling implementation as provided in constructor
  # @property signaling
  # @type rtc.signaling.Signaling
  ###

  ###*
  # The local peer
  # @property local
  # @type rtc.LocalPeer
  ###

  constructor: (@signaling, @options={}) ->
    # turn signaling into acctual signaling if needed
    if typeof @signaling == 'string' or @signaling instanceof String
      channel = new WebSocketChannel(@signaling)
      @signaling = new MucSignaling(channel)

    @local = @options.local || new LocalPeer()

    @signaling.setStatus(@local._status)

    @local.on 'status_changed', () =>
      @signaling.setStatus(@local._status)

    @signaling.on 'peer_joined', (signaling_peer) =>
      pc = new PeerConnection(signaling_peer.first, @options)
      peer = @createPeer(pc, signaling_peer)

      peer.on 'status_changed', (status) =>
        @emit('peer_status_changed', peer, status)

      peer.on 'left', () =>
        delete @peers[signaling_peer.id]
        @emit('peer_left', peer)

      @peers[signaling_peer.id] = peer
      @emit('peer_joined', peer)

      peer.on 'closed', () =>
        delete @peers[signaling_peer.id]

    @peers = {}


  ###*
  # Joins the room. Initiates connection to signaling server if not done before.
  # @method join
  # @return {Promise} A promise which will be resolved once the room was joined
  ###
  connect: () ->
    if not @join_p?
      @join_p = @signaling.connect()

    return @join_p


  ###*
  # Leaves the room and closes all established peer connections
  # @method leave
  ###
  leave: () ->
    return @signaling.leave()


  ###*
  # Cleans up all resources used by the room.
  # @method leave
  ###
  destroy: () ->
    # TODO ...
    return @signaling.leave()


  ###*
  # Creates a remote peer. Overwrite to use your own class for peers.
  # @private
  # @method create_peer
  # @param {rtc.PeerConnection} pc The PeerConnection to the peer
  # @param {rtc.SignalingPeer} signaling_peer The signaling connection to the peer
  ###
  createPeer: (pc, signaling_peer) ->
    return new RemotePeer(pc, signaling_peer, @local, @options)
