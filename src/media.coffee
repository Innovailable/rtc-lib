q = require('q')

rtc = require('./lib')

exports.media = media = {}


media.createStream = (obj={audio:true, video: true}) ->
  stream_d = q.defer()

  if obj instanceof rtc.compat.MediaStream
    stream_d.resolve(new rtc.Stream(obj))
  else
    success = (stream) ->
      stream_d.resolve(new rtc.Stream(stream))

    error = (err) ->
      # TODO: convert error?
      stream_d.reject(err)

    rtc.compat.getUserMedia(obj, success, error)

  return stream_d.promise

