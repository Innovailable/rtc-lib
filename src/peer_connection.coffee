q = require('q')

EventEmitter = require('events').EventEmitter

compat = require('./compat').compat

class exports.PeerConnection extends EventEmitter

  constructor: (@signaling, @offering, @options) ->
    @pc = new compat.PeerConnection(@iceOptions())

    @connect_d = q.defer()
    @connected = false

    # signaling

    @signaling.on 'signaling', (data) =>
      sdp = new compat.SessionDescription(data)

      @setRemoteDescription(sdp).then () =>
        if data.type == 'offer' and @connected
          return @answer()
      .fail (err) =>
        @connectError(err)
      .done()

    @signaling.on 'ice_candidate', (desc) =>
      if desc.candidate?
        candidate = new rtc.compat.IceCandidate(desc)
        @pc.addIceCandidate(candidate)
      else
        # TODO: end of ice trickling ... do something?
        console.log("ICE trickling stopped")

    @signaling.on 'error', (err) =>
      # TODO: better error
      @connect_d.reject(new Error("Error from remote: " + err))

    # PeerConnection events

    @pc.onicecandidate = (event) =>
      @signaling.send('ice_candidate', event.candidate)

    @pc.onaddstream = (event) =>
      @emit('stream_added', event.stream)

    @pc.ondatachannel = (event) ->
      # TODO

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


  iceOptions: () ->
    servers = []

    if @options.stun?
      servers.push({url: @options.stun})

    # TODO: turn

    return {
      iceServers: servers
    }


  oaOptions: () ->
    return {
      optional: []
      mandatory: {
        OfferToReceiveAudio: true
        OfferToReceiveVideo: true
      }
    }


  setRemoteDescription: (sdp) ->
    res_d = q.defer()

    description = new rtc.compat.SessionDescription(sdp)

    @pc.setRemoteDescription(sdp, res_d.resolve, res_d.reject)

    return res_d.promise


  offer: () ->
    res_d = q.defer()

    @pc.createOffer(res_d.resolve, res_d.reject, @oaOptions())

    res_d.promise.then (sdp) =>
      return @processLocalSdp(sdp)
    .fail (err) =>
      @connectError(err)
    .done()


  answer: () ->
    res_d = q.defer()

    @pc.createAnswer(res_d.resolve, res_d.reject, @oaOptions())

    res_d.promise.then (sdp) =>
      return @processLocalSdp(sdp)
    .fail (err) =>
      @connectError(err)
    .done()


  processLocalSdp: (sdp) ->
    res_d = q.defer()

    success = () =>
      @signaling.send('signaling', sdp)
      res_d.resolve(sdp)

    @pc.setLocalDescription(sdp, success, res_d.reject)

    return res_d.promise


  connectError: (err) ->
    # TODO: better errors
    @connect_d.reject(err)
    @signaling.send('error', err.message)
    console.log(err)


  addStream: (stream) ->
    @pc.addStream(stream.stream)


  removeSream: (stream) ->
    @pc.removeStream(stream.stream)


  connect: () ->
    if not @connected
      if @offering
        # we are starting the process
        @offer()
      else if @pc.signalingState == 'have-remote-offer'
        # the other party is already waiting
        @answer()

      @connected = true

    return @connect_d.promise


  close: () ->
    @pc.close()
    @emit 'closed'

