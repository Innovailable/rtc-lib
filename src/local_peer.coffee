q = require('q')

rtc = require('./lib')

class LocalPeer

  constructor: (status={}) ->
    @streams = {}
    @channels = {}


  addStream: (label, obj) ->
    # helper to actually save stream
    saveStream = (stream_p) =>
      stream_p.then (stream) ->
        stream.setLabel(label)

      # TODO: collision detection?
      @streams[label] = stream_p

    # label can be omitted ... once!
    if typeof label != 'string' and not obj?
      # TODO: automagic labels?
      label = 'stream'
      obj = label

    if typeof obj == 'function'
      # it is a promise
      setStream(obj)
    else if stream instanceof stream
      # it is the actual stream, turn into promise
      setStream(q(obj))
    else
      # we assume we can pass it on to create a stream
      stream_p = rtc.media.createStream(obj)
      setStream(stream_p)


exports.LocalPeer = LocalPeer
