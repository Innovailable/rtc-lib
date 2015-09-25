Stream = require('./stream').Stream
Peer = require('./peer').Peer


class exports.MediaDomElement

  constructor: (@dom, data) ->
    if @dom.jquery?
      # TODO: warn if less/more than one element
      @dom = @dom[0]

    @attach(data)


  attach: (data) ->
    # TODO: handle conflict between multiple calls
    if not data?
      # TODO: support empty data with placeholder
    else if data instanceof Stream
      if mozGetUserMedia?
        @dom.mozSrcObject = data.stream
      else
        @dom.src = URL.createObjectURL(data.stream)

      @dom.play()
    else if data instanceof Peer
      @attach(data.stream())
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
    console.log(err)
    @dom.stop()


  clear: () ->
    @dom.stop()
    @dom.src = null


  mute: (muted=true) ->
    @dom.muted = muted


  toggleMute: () ->
    @dom.muted = !@dom.muted
