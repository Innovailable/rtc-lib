Stream = require('./stream').Stream
Peer = require('./peer').Peer


class exports.MediaDomElement

  constructor: (@dom, data) ->
    if @dom.jquery?
      # TODO: warn if less/more than one element
      @dom = @dom[0]

    # TODO: we want promises!

    if data?
      if data instanceof Stream
        @attachStream(data)
      else if data instanceof Peer
        @attachPeer(data)
      else
        # TODO: warn?


  attachPeer: (peer) ->


  attachStream: (stream) ->
    if mozGetUserMedia?
      @dom.mozSrcObject = stream.stream
    else
      @dom.src = URL.createObjectURL(stream.stream)

    @dom.play()


  clear: () ->
    @dom.stop()
    @dom.src = null


  mute: (muted=true) ->
    @dom.muted = muted


  toggleMute: () ->
    @dom.muted = !@dom.muted
