q = require('q')

EventEmitter = require('events').EventEmitter

Stream = require('./stream').Stream
DataChannel = require('./data_channel').DataChannel

compat = require('./compat').compat

class exports.PeerConnection extends EventEmitter

  constructor: (@offering, @options) ->
    @pc = new compat.PeerConnection(@iceOptions())

    @connect_d = q.defer()
    @connected = false

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

    @setRemoteDescription(sdp).then () =>
      if data.type == 'offer' and @connected
        return @answer()
    .fail (err) =>
      @connectError(err)
    .done()


  addIceCandidate: (desc) ->
    if desc.candidate?
      candidate = new rtc.compat.IceCandidate(desc)
      @pc.addIceCandidate(candidate)
    else
      # TODO: end of ice trickling ... do something?
      console.log("ICE trickling stopped")


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
      data  = {
        sdp: sdp.sdp
        type: sdp.type
      }

      @emit('signaling', data)
      res_d.resolve(sdp)

    @pc.setLocalDescription(sdp, success, res_d.reject)

    return res_d.promise


  connectError: (err) ->
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
        @emit('data_channel_added', new DataChannel(channel))


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

