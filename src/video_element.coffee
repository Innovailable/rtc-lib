Stream = require('./stream').Stream
Peer = require('./peer').Peer


###*
# @module rtc
###
###*
# @class rtc.MediaDomElement
###
class exports.MediaDomElement

  constructor: (@dom, data) ->
    if @dom.jquery?
      # TODO: warn if less/more than one element
      @dom = @dom[0]

    @attach(data)


  attach: (data) ->
    # TODO: handle conflict between multiple calls
    if not data?
      delete @stream

      @dom.pause()
      @dom.src = null

    else if data instanceof Stream
      @stream = data

      if mozGetUserMedia?
        @dom.mozSrcObject = data.stream
      else
        @dom.src = URL.createObjectURL(data.stream)

      @dom.play()

    else if data instanceof Peer
      if data.isLocal()
        @mute()

      @attach(data.stream())

    else if data?.then?
      data.then (res) =>
        @attach(res)
      .catch (err) =>
        @error(err)

    else
      @error("Tried to attach invalid data")


  error: (err) ->
    # TODO: do more with dom
    console.log(err)


  clear: () ->
    @attach()


  mute: (muted=true) ->
    @dom.muted = muted


  toggleMute: () ->
    @dom.muted = !@dom.muted
