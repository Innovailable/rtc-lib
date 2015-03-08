q = require('q')

rtc = require('./lib')

exports.media = media = {}

next_id = 0

media.createStream = (obj={audio: true, video: true}) ->
  stream_d = q.defer()

  if obj instanceof rtc.compat.MediaStream
    # an actual stream
    stream_d.resolve(new rtc.Stream(obj))
  else if typeof obj == 'function'
    # promise for a stream
    obj.then (native_stream) ->
      stream_d.resolve(new rtc.Stream(native_stream))
  else
    # description to pass to getUserMedia()
    success = (native_stream) ->
      stream_d.resolve(new rtc.Stream(native_stream))

    error = (err) ->
      # TODO: convert error?
      stream_d.reject(err)

    rtc.compat.getUserMedia(obj, success, error)

  return stream_d.promise

