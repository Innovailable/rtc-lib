q = require('q')

rtc = require('./lib')

class exports.LocalPeer extends rtc.Peer

  constructor: (@status_obj={}) ->
    @streams = {}
    @channels = {}


  status: (key, value) ->
    if key? and value?
      @status_obj[key] = value
      @emit 'status_changed', @status_obj
      return
    else if key?
      return @status_obj[key]
    else
      return @status_obj


  dataChannel: (name=@DEFAULT_CHANNEL) ->
    return @channels[name]


  addDataChanenl: (name, desc) ->
    if typeof name != 'string'
      desc = name
      name = @DEFAULT_CHANNEL

    @channels[name] = desc
    @emit 'configuration_changed'
    return


  removeDataChannel: (name) ->
    delete @channels[name]
    @emit 'configuration_changed'
    return


  stream: (name=@DEFAULT_STREAM) ->
    return @streams[name]


  addStream: (name, obj) ->
    # helper to actually save stream
    saveStream = (stream_p) =>
      # TODO: collision detection?
      @streams[name] = stream_p
      @emit 'configuration_changed'
      return stream_p

    # name can be omitted ... once
    if typeof name != 'string'
      # TODO: automagic labels?
      obj = name
      name = @DEFAULT_STREAM

    if typeof obj == 'function'
      # it is a promise
      return setStream(obj)
    else if stream instanceof stream
      # it is the actual stream, turn into promise
      return setStream(q(obj))
    else
      # we assume we can pass it on to create a stream
      stream_p = rtc.media.createStream(label, obj)
      return setStream(stream_p)


  removeStream: (name) ->
    delete @streams[name]
    @emit 'configuration_changed'
    return

