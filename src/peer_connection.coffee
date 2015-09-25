Deferred = require('es6-deferred')
EventEmitter = require('events').EventEmitter
Promise = require('./compat').compat.Promise

Stream = require('./stream').Stream
DataChannel = require('./data_channel').DataChannel

compat = require('./compat').compat

class exports.PeerConnection extends EventEmitter

  constructor: (@offering, @options) ->
    @pc = new compat.PeerConnection(@_iceOptions())

    @connect_d = new Deferred()
    @connected = false

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
      if @pc.iceConnectionState in ['failed', 'closed']
        connectionError(new Error("Unable to establish ICE connection"))
      else if @pc.iceConnectionState in ['connected', 'completed']
        @connect_d.resolve()

    @pc.onsignalingstatechange = (event) ->
      #console.log(event)


  signaling: (data) ->
    sdp = new compat.SessionDescription(data)

    @_setRemoteDescription(sdp).then () =>
      if data.type == 'offer' and @connected
        return @_answer()
    .catch (err) =>
      @_connectError(err)


  addIceCandidate: (desc) ->
    if desc.candidate?
      candidate = new rtc.compat.IceCandidate(desc)
      @pc.addIceCandidate(candidate)
    else
      # TODO: end of ice trickling ... do something?
      console.log("ICE trickling stopped")


  _iceOptions: () ->
    servers = []

    if @options.stun?
      servers.push({url: @options.stun})

    # TODO: turn

    return {
      iceServers: servers
    }


  _oaOptions: () ->
    return {
      optional: []
      mandatory: {
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true
      }
    }


  _setRemoteDescription: (sdp) ->
    return new Promise (resolve, reject) =>
      description = new rtc.compat.SessionDescription(sdp)
      @pc.setRemoteDescription(sdp, resolve, reject)


  _offer: () ->
    return new Promise (resolve, reject) =>
      @pc.createOffer(resolve, reject, @_oaOptions())
    .then (sdp) =>
      return @_processLocalSdp(sdp)
    .catch (err) =>
      @_connectError(err)


  _answer: () ->
    new Promise (resolve, reject) =>
      @pc.createAnswer(resolve, reject, @_oaOptions())
    .then (sdp) =>
      return @_processLocalSdp(sdp)
    .catch (err) =>
      @_connectError(err)


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


  _connectError: (err) ->
    # TODO: better errors
    @connect_d.reject(err)
    console.log(err)
    @emit('error', err)


  addStream: (stream) ->
    @pc.addStream(stream.stream)


  removeSream: (stream) ->
    @pc.removeStream(stream.stream)


  addDataChannel: (name, options) ->
    if @offering
      channel = @pc.createDataChannel(name, options)

      channel.onopen = () =>
        @emit('data_channel_ready', new DataChannel(channel))


  connect: () ->
    if not @connected
      if @offering
        # we are starting the process
        @_offer()
      else if @pc.signalingState == 'have-remote-offer'
        # the other party is already waiting
        @_answer()

      @connected = true

    return @connect_d.promise


  close: () ->
    @pc.close()
    @emit 'closed'

