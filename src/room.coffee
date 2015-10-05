EventEmitter = require('events').EventEmitter

{WebSocketChannel} = require('./signaling/web_socket_channel.coffee')
{MucSignaling} = require('./signaling/muc_signaling.coffee')

RemotePeer = require('./remote_peer.coffee').RemotePeer
LocalPeer = require('./local_peer.coffee').LocalPeer
PeerConnection = require('./peer_connection.coffee').PeerConnection

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
  # The connection to the room was closed
  # @event closed
  ###

  constructor: (@signaling, @options={}) ->
    # turn signaling into acctual signaling if needed
    if typeof @signaling == 'string' or @signaling instanceof String
      channel = new WebSocketChannel(@signaling)
      @signaling = new MucSignaling(channel)

    @local = @options.local || new LocalPeer()

    @signaling.on 'peer_joined', (signaling_peer) =>
      pc = new PeerConnection(signaling_peer.first, @options)
      peer = new RemotePeer(pc, signaling_peer, @local, @options)

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
