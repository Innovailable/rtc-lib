Peer = require('./peer').Peer
Stream = require('./stream').Stream


class exports.LocalPeer extends Peer

  @streams: {}

  constructor: (@status_obj={}) ->
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


  addDataChannel: (name, desc) ->
    if typeof name != 'string'
      desc = name
      name = @DEFAULT_CHANNEL

    if not desc?
      desc = {
        ordered: true
      }

    @channels[name] = desc
    @emit 'configuration_changed'
    return


  removeDataChannel: (name) ->
    delete @channels[name]
    @emit 'configuration_changed'
    return


  addStream: (name, obj) ->
    # helper to actually save stream
    saveStream = (stream_p) =>
      # TODO: collision detection?
      @streams[name] = stream_p
      @emit 'configuration_changed'
      return stream_p

    # name can be omitted ... once
    if typeof name != 'string'
      obj = name
      name = @DEFAULT_STREAM

    if obj?.then?
      # it is a promise
      return saveStream(obj)
    else if obj instanceof Stream
      # it is the actual stream, turn into promise
      return saveStream(Promise.resolve(obj))
    else
      # we assume we can pass it on to create a stream
      stream_p = rtc.media.createStream(obj)
      return saveStream(stream_p)


  removeStream: (name) ->
    delete @streams[name]
    @emit 'configuration_changed'
    return


  stream: (name=@DEFAULT_STREAM) ->
    return @streams[name]
