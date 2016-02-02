{compat} = require('./compat')
{EventEmitter} = require('events')


###*
# @module rtc
###
###*
# A wrapper around an HTML5 MediaStream
# @class rtc.Stream
#
# @constructor
# @param {RTCDataStream} stream The native stream
###
class exports.Stream extends EventEmitter

  ###*
  # Emitted when tracks are muted or unmuted. Only triggered when changes are
  # made through this objects mute functions.
  # @event mute_changed
  # @param {'audio' | 'video' | 'both'} type The type of tracks which changed
  # @param {Boolean} muted `true` if tracks were muted, `false` if they were unmuted
  ###

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
      return @stream.getAudioTracks()
    else if type == 'video'
      return @stream.getVideoTracks()
    else if type == 'both'
      video = @stream.getVideoTracks()
      vaudio = @stream.getAudioTracks()
      return video.concat(audio)
    else
      throw new Error("Invalid stream part '" + type + "'")


  ###*
  # Checks whether a type of track is muted. If there are no tracks of the
  # specified type they will be considered muted
  # @param {'audio' | 'video' | 'both'} [type='audio'] The type of tracks
  # @return {Boolean} Whether the tracks are muted
  ###
  muted: (type='audio') ->
    tracks = @getTracks(type)

    if tracks.length < 1
      return true

    return not tracks[0]?.enabled


  ###*
  # Mutes or unmutes tracks of the stream
  # @method mute
  # @param {Boolean} [muted=true] Mute on `true` and unmute on `false`
  # @param {'audio' | 'video' | 'both'} [type='audio'] The type of tracks to mute or unmute
  # @return {Boolean} Whether the tracks were muted or unmuted
  ###
  mute: (muted=true, type='audio') ->
    for track in @getTracks(type)
      track.enabled = not muted

    @emit('mute_changed', type, muted)

    return muted


  ###*
  # Toggles the mute state of tracks of the stream
  # @method toggleMute
  # @param {'audio' | 'video' | 'both'} [type='audio'] The type of tracks to mute or unmute
  # @return {Boolean} Whether the tracks were muted or unmuted
  ###
  toggleMute: (type='audio') ->
    tracks = @getTracks(type)

    if tracks.length < 1
      return true

    muted = not tracks[0]?.enabled

    for track in tracks
      track.enabled = not muted

    @emit('mute_changed', type, muted)

    return muted


  ###*
  # Stops the stream
  # @method stop
  ###
  stop: () ->
    if @stream.getTracks?
      for track in @stream.getTracks()
        track.stop()
    else
      @stream.stop()


  ###*
  # Clones the stream. You can change both streams independently, for example
  # mute tracks. You will have to `stop()` both streams individually when you
  # are done.
  #
  # This is currently not supported in Firefox and expected to be implemented
  # in version 47. Use `Stream.canClone()` to check whether cloning is supported by
  # your browser.
  #
  # @method clone
  # @return {rtc.Stream} A clone of the stream
  ###
  clone: () ->
    if not @stream.clone?
      throw new Error("Your browser does not support stream cloning. Firefox is expected to implement it in version 47.")

    return new Stream(@stream.clone())


  ###*
  # Checks whether cloning stream is supported by the browser. See `clone()`
  # for details
  # @static
  # @method canClone
  # @return {Boolean} `true` if cloning is supported, `false` otherwise
  ###
  @canClone: () ->
    return compat.MediaStream.prototype.clone?


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

