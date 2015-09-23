Stream = require('./stream').Stream
Peer = require('./peer').Peer


class exports.MediaDomElement

  constructor: (@dom, data) ->
    if @dom.jquery?
      # TODO: warn if less/more than one element
      @dom = @dom[0]

    if data?
      @attach(data)


  attach: (data) ->
    if data instanceof Stream
      if mozGetUserMedia?
        @dom.mozSrcObject = data.stream
      else
        @dom.src = URL.createObjectURL(data.stream)

      @dom.play()
    else if data instanceof Peer
      stream = data.stream()

      if stream?
        @attach(stream)
      else
        @error("Peer does not have a default stream")
    else if data?.then?
      data.then (res) =>
        @attach(res)
      .fail (err) =>
        @error(err)
      .done()
    else
      @error("Tried to attach invalid data")


  error: (err) ->
    # TODO: do more with dom
    @dom.stop()
    console.log(err)


  clear: () ->
    @dom.stop()
    @dom.src = null


  mute: (muted=true) ->
    @dom.muted = muted


  toggleMute: () ->
    @dom.muted = !@dom.muted
