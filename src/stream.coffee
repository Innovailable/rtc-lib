{compat} = require('./compat')


###*
# A wrapper around an HTML5 MediaStream
# @module rtc
# @class rtc.Stream
#
# @constructor
# @param {RTCDataStream} stream The native stream
###
class exports.Stream

  constructor: (@stream) ->


  ###*
  # Get the id of the stream. This is neither user defined nor human readable.
  # @method id
  # @return {String} The id of the underlying stream
  ###
  id: () ->
    return @stream.id


  ###*
  # Checks whether the stream has any tracks of the given type
  # @method hasTracks
  # @param {'audio' | 'video' | 'both'} [type='both'] The type of track to check for
  # @return {Number} The amount of tracks of the given type
  ###
  hasTracks: (type) ->
    return @getTracks(type).length


  ###*
  # Gets the tracks of the given type
  # @method getTracks
  # @param {'audio' | 'video' | 'both'} [type='both'] The type of tracks to get
  # @return {Array} An Array of the tracks
  ###
  getTracks: (type) ->
    type = type.toLowerCase()

    if type == 'audio'
      return @stream_p.then (stream) ->
        return stream.getAudioTracks()
    else if type == 'video'
      return @stream_p.then (stream) ->
        return stream.getVideoTracks()
    else if type == 'both'
      return @stream_p.then (stream) ->
        video = stream.getVideoTracks()
        vaudio = stream.getAudioTracks()
        return video.concat(audio)
    else
      throw new Error("Invalid stream part '" + type + "'")


  ###*
  # Mutes or unmutes tracks of the stream
  # @method mute
  # @param {Boolean} [muted=true] Mute on `true` and unmute on `false`
  # @param {'audio' | 'video' | 'both'} [type='audio'] The type of tracks to mute or unmute
  # @return {Boolean} Whether the tracks were muted or unmuted
  ###
  mute: (muted=true, type='audio') ->
    for track in getTracks(type)
      track.enabled = not muted

    return muted


  ###*
  # Toggles the mute state of tracks of the stream
  # @method toggleMute
  # @param {'audio' | 'video' | 'both'} [type='audio'] The type of tracks to mute or unmute
  # @return {Boolean} Whether the tracks were muted or unmuted
  ###
  toggleMute: (type='audio') ->
    tracks = getTracks(type)

    muted = not tracks[0]?.enabled

    for track in tracks
      track.enabled = not muted

    return muted


  ###*
  # Stops the stream
  # @method stop
  ###
  stop: () ->
    stream.stop()


  ###*
  # Creates a stream using `getUserMedia()`
  # @method createStream
  # @static
  # @param {Object} [config={audio: true, video: true}] The configuration to pass to `getUserMedia()`
  # @return {Promise -> rtc.Stream} Promise to the stream
  #
  # @example
  #     var stream = rtc.Stream.createStream({audio: true, video: false});
  #     rtc.MediaDomElement($('video'), stream);
  ###
  @createStream: (config={audio: true, video: true}) ->
    return new Promise (resolve, reject) ->
      # description to pass to getUserMedia()
      success = (native_stream) ->
        resolve(new Stream(native_stream))

      compat.getUserMedia(config, success, reject)
