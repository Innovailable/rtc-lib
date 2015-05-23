q = require('q')
events = require('events')

rtc = require('./lib')

class exports.PeerConnection extends events.EventEmitter

  constructor: (@direct_channel, @offering, @options) ->
    @pc = rtc.compat.PeerConnection(iceOptions())

    @connect_d = q.defer()
    @connected = false

    # signaling

    @direct_channel.on 'signaling', (sdp) ->
      setRemoteSdp.then () ->
        if sdp.type == 'offer' and @connected
          answer()
        
        return
      , (err) ->
        connectError(err)

    @direct_channel.on 'ice_candidate', (desc) =>
      candidate = new rtc.compat.IceCandidate(desc)
      @pc.addIceCandidate(candidate)

    @direct_channel.on 'error', (err) =>
      # TODO: better error
      @connect_d.reject(new Error("Error from remote: " + err))

    # PeerConnection events

    @pc.onicecandidate = (event) =>
      @direct_channel.send('ice_candidate', event.candidate)

    @pc.onaddstream = (event) ->
      # TODO

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
        @connected_d.resolve()

    @pc.onsignalingstatechange = (event) ->
      # TODO


  iceOptions = () ->
    servers = []

    if @options.stun?
      servers.push({url: @options.stun})

    # TODO: turn

    return {
      iceServers: servers
    }


  oaOptions = () ->
    return {
      offerToReceiveAudio: 1
      offerToReceiveVideo: 1
    }


  setRemoteDescription = ->
    res_d = q.defer()

    description = new rtc.compat.SessionDescription(sdp)

    @pc.setRemoteDescription(sdp, res_d.resolve, res_d.reject)

    return res_d.promise


  offer = () ->
    res_d = q.defer()
    @pc.createOffer(res_d.resolve, res_d.reject, oaOptions())
    res_d.promise.then(processLocalSdp).fail (err) ->
      connectError(err)


  answer = () ->
    res_d = q.defer()
    @pc.createAnswer(res_d.resolve, res_d.reject, oaOptions())
    res_d.promise.then(processLocalSdp).fail (err) ->
      connectError(err)


  processLocalSdp = (sdp) ->
    res_d = q.defer()

    success = () =>
      @direct_channel.send('signaling', sdp)
      res_d.resolve(sdp)

    @pc.setLocalDescription(success, res_d.reject)

    return res_d.promise


  connectError = (err) ->
    # TODO: better errors
    @connect_d.reject(err)
    @direct_channel.send('error', err.message)


  addStream: (stream) ->
    @pc.addStream(stream.stream)


  removeSream: (stream) ->
    @pc.removeStream(stream.stream)


  connect: () ->
    if not @connected
      if @offering
        # we are starting the process
        offer()
      else if @pc.signalingState == 'have-remote-offer'
        # the other party is already waiting
        answer()

      @connected = true

    return @connect_d.promise


  close: () ->
    @pc.close()
    @emit 'closed'

