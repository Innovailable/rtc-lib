{Deferred,Promise} = require('./internal/promise')
EventEmitter = require('events').EventEmitter

Stream = require('./stream').Stream
DataChannel = require('./data_channel').DataChannel

compat = require('./compat').compat

###*
# @module rtc
###
###*
# Wrapper around native RTCPeerConnection
#
# Provides events for new streams and data channels. Signaling information has
# to be forwarded from events emitted by this object to the remote
# PeerConnection.
#
# @class rtc.PeerConnection
# @extends events.EventEmitter
#
# @constructor
# @param {Boolean} offering True if the local peer should initiate the connection
# @param {Object} options Options object passed on from `Room`
###
class exports.PeerConnection extends EventEmitter

  ###*
  # New local ICE candidate which should be signaled to remote peer
  # @event ice_candiate
  # @param {Object} candidate The ice candidate
  ###

  ###*
  # New remote stream was added to the PeerConnection
  # @event stream_added
  # @param {rtc.Stream} stream The stream
  ###

  ###*
  # New DataChannel to the remote peer is ready to be used
  # @event data_channel_ready
  # @param {rtc.DataChannel} channel The data channel
  ###

  ###*
  # New offer or answer which should be signaled to the remote peer
  # @event signaling
  # @param {Object} obj The signaling message
  ###

  ###*
  # The PeerConnection was closed
  # @event closed
  ###

  constructor: (@offering, @options) ->
    ice_servers = []
    @no_gc_bugfix = []

    if @options.stun?
      ice_servers.push({url: @options.stun})

    if @options.turn?
      ice_servers.push(@options.turn)

    # TODO: STUN

    @pc = new compat.PeerConnection({iceServers: ice_servers})

    @connect_d = new Deferred()
    @connected = false

    @connect_d.promise.catch(() ->)

    @signaling_pending = []

    # PeerConnection events

    @pc.onicecandidate = (event) =>
      @emit('ice_candidate', event.candidate)

    @pc.onaddstream = (event) =>
      @emit('stream_added', new Stream(event.stream))

    @pc.ondatachannel = (event) =>
      @emit('data_channel_ready', new DataChannel(event.channel))

    @pc.onremovestream = (event) ->
      # TODO

    @pc.onnegotiationneeded = (event) =>
      # TODO
      console.log 'onnegotiationneeded called'

    # PeerConnection states

    @pc.oniceconnectionstatechange = () =>
      if @pc.iceConnectionState == 'failed'
        @_connectError(new Error("Unable to establish ICE connection"))
      else if @pc.iceConnectionState == 'closed'
        @connect_d.reject(new Error('Connection was closed'))
      else if @pc.iceConnectionState in ['connected', 'completed']
        @connect_d.resolve()

    @pc.onsignalingstatechange = (event) ->
      #console.log(event)


  ###*
  # Add new signaling information received from remote peer
  # @method signaling
  # @param {Object} data The signaling information
  ####
  signaling: (data) ->
    sdp = new compat.SessionDescription(data)

    @_setRemoteDescription(sdp).then () =>
      if data.type == 'offer' and @connected
        return @_answer()
    .catch (err) =>
      @_connectError(err)


  ###*
  # Add a remote ICE candidate
  # @method addIceCandidate
  # @param {Object} desc The candidate
  ###
  addIceCandidate: (desc) ->
    if desc?.candidate?
      candidate = new compat.IceCandidate(desc)
      @pc.addIceCandidate(candidate)
    else
      # TODO: end of ice trickling ... do something?
      console.log("ICE trickling stopped")


  ###*
  # Returns the options for the offer/answer
  # @method _oaOptions
  # @private
  # @return {Object}
  ###
  _oaOptions: () ->
    return {
      optional: []
      mandatory: {
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true
      }
    }


  ###*
  # Set the remote description
  # @method _setRemoteDescription
  # @private
  # @param {Object} sdp The remote SDP
  # @return {Promise} Promise which will be resolved once the remote description was set successfully
  ###
  _setRemoteDescription: (sdp) ->
    return new Promise (resolve, reject) =>
      description = new compat.SessionDescription(sdp)
      @pc.setRemoteDescription(sdp, resolve, reject)


  ###*
  # Create offer, set it on local description and emit it
  # @method _offer
  # @private
  ###
  _offer: () ->
    return new Promise (resolve, reject) =>
      @pc.createOffer(resolve, reject, @_oaOptions())
    .then (sdp) =>
      return @_processLocalSdp(sdp)
    .catch (err) =>
      @_connectError(err)


  ###*
  # Create answer, set it on local description and emit it
  # @method _offer
  # @private
  ###
  _answer: () ->
    new Promise (resolve, reject) =>
      @pc.createAnswer(resolve, reject, @_oaOptions())
    .then (sdp) =>
      return @_processLocalSdp(sdp)
    .catch (err) =>
      @_connectError(err)


  ###*
  # Set local description and emit it
  # @method _processLocalSdp
  # @private
  # @param {Object} sdp The local SDP
  # @return {Promise} Promise which will be resolved once the local description was set successfully
  ###
  _processLocalSdp: (sdp) ->
    new Promise (resolve, reject) =>
      success = () =>
        data  = {
          sdp: sdp.sdp
          type: sdp.type
        }

        @emit('signaling', data)
        resolve(sdp)

      @pc.setLocalDescription(sdp, success, reject)


  ###*
  # Mark connection attempt as failed
  # @method _connectError
  # @private
  # @param {Error} err Error causing connection to fail
  ###
  _connectError: (err) ->
    # TODO: better errors
    @connect_d.reject(err)
    console.log(err)
    @emit('error', err)


  ###*
  # Add local stream
  # @method addStream
  # @param {rtc.Stream} stream The local stream
  ###
  addStream: (stream) ->
    @pc.addStream(stream.stream)


  ###*
  # Remove local stream
  # @method removeStream
  # @param {rtc.Stream} stream The local stream
  ###
  removeSream: (stream) ->
    @pc.removeStream(stream.stream)


  ###*
  # Add DataChannel. Will only actually do something if `offering` is `true`.
  # @method addDataChannel
  # @param {String} name Name of the data channel
  # @param {Object} desc Options passed to `RTCPeerConnection.createDataChannel()`
  ###
  addDataChannel: (name, options) ->
    if @offering
      channel = @pc.createDataChannel(name, options)

      # Don't let the channel be garbage collected
      # We only pass it on in onopen callback so the gc is not clever enough to let this live ...
      # https://code.google.com/p/chromium/issues/detail?id=405545
      # https://bugzilla.mozilla.org/show_bug.cgi?id=964092
      @no_gc_bugfix.push(channel)

      channel.onopen = () =>
        @emit('data_channel_ready', new DataChannel(channel))


  ###*
  # Establish connection with remote peer. Connection will be established once both peers have called this functio
  # @method connect
  # @return {Promise} Promise which will be resolved once the connection is established
  ###
  connect: () ->
    if not @connected
      if @offering
        # we are starting the process
        @_offer()
      else if @pc.signalingState == 'have-remote-offer'
        # the other party is already waiting
        @_answer()

      @connected = true

    return Promise.resolve(@connect_d.promise)


  ###*
  # Close the connection to the remote peer
  # @method close
  ###
  close: () ->
    @pc.close()
    @emit 'closed'

