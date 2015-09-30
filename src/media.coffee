{Deferred} = require('./internal/promise')

compat = require('./compat').compat
Stream = require('./stream').Stream

exports.media = media = {}

next_id = 0

media.createStream = (obj={audio: true, video: true}) ->
  # TODO: move from Deferred() to Promise()
  stream_d = new Deferred()

  if obj instanceof compat.MediaStream
    # an actual native stream
    stream_d.resolve(new Stream(obj))
  else if obj?.then?
    # promise for a stream
    obj.then (native_stream) ->
      stream_d.resolve(new Stream(native_stream))
  else
    # description to pass to getUserMedia()
    success = (native_stream) ->
      stream_d.resolve(new Stream(native_stream))

    error = (err) ->
      # TODO: convert error?
      stream_d.reject(err)

    compat.getUserMedia(obj, success, error)

  return stream_d.promise

