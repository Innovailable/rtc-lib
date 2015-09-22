EventEmitter = require('events').EventEmitter

WebSocketChannel = require('./signaling/web_socket_channel.coffee').WebSocketChannel
PalavaSignaling = require('./signaling/palava_signaling.coffee').PalavaSignaling

RemotePeer = require('./remote_peer.coffee').RemotePeer
LocalPeer = require('./local_peer.coffee').LocalPeer
PeerConnection = require('./peer_connection.coffee').PeerConnection

class exports.Room extends EventEmitter

  constructor: (@name, @signaling, @options={}) ->
    # turn signaling into acctual signaling if needed
    if typeof @signaling == 'string' or @signaling instanceof String
      channel = new WebSocketChannel(@signaling)
      @signaling = new PalavaSignaling(channel)

    @local = new LocalPeer()

    @signaling.on 'peer_joined', (signaling_peer) =>
      pc = new PeerConnection(signaling_peer, signaling_peer.first, @options)
      peer = new RemotePeer(pc, signaling_peer, @local)

      @peers[signaling_peer.id] = peer
      @emit('peer_joined', peer)

    @peers = {}


  join: () ->
    if not @join_p?
      streams = {}

      for name, stream_promise of @local.streams
        state = stream_promise.inspect()

        if state.value
          streams[name] = state.value.id()
        else
          streams[name] = undefined

      @join_p = @signaling.join(@name, @local.status(), streams, {})

    return @join_p


  leave: () ->
    return @signaling.leave()


  destroy: () ->
    # TODO ...
    return @signaling.leave()
