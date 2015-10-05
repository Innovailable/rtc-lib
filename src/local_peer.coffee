Peer = require('./peer').Peer
Stream = require('./stream').Stream

###*
# @module rtc
###
###*
# Represents the local user of the room
# @class rtc.LocalPeer
# @extends rtc.Peer
#
# @constructor
###
class exports.LocalPeer extends Peer

  constructor: () ->
    ###*
    # Contains promises of the local streams offered to all remote peers
    # @property streams
    # @type Object
    ###
    @streams = {}

    ###*
    # Contains all DataChannel configurations negotiated with all remote peers
    # @property channels
    # @type Object
    ###
    @channels = {}

    @_status = {}


  ###*
  # Get an item of the status transferred to all remote peers
  # @method status
  # @param {String} key The key of the value. Will return
  # @return The value associated with the key
  ###
  ###*
  # Set an item of the status transferred to all remote peers
  # @method status
  # @param {String} key The key of the value. Will return
  # @param value The value to store
  ###
  status: (key, value) ->
    if value?
      @_status[key] = value
      @emit 'status_changed', @_status
      return
    else
      return @_status[key]


  ###*
  # Add data channel which will be negotiated with all remote peers
  # @method addDataChannel
  # @param {String} [name='data'] Name of the data channel
  # @param {Object} [desc] Options passed to `RTCDataChannel.createDataChannel()`
  ###
  addDataChannel: (name, desc) ->
    if typeof name != 'string'
      desc = name
      name = @DEFAULT_CHANNEL

    if not desc?
      # TODO: default handling
      desc = {
        ordered: true
      }

    @channels[name] = desc
    @emit 'configuration_changed'
    return


  ###*
  # Add local stream to be sent to all remote peers
  # @method addStream
  # @param {String} [name='stream'] Name of the stream
  # @param {Promise -> rtc.Stream | rtc.Stream | Object} stream The stream, a promise to the stream or the configuration to create a stream with `rtc.Stream.createStream()`
  ###
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
      stream_p = Stream.createStream(obj)
      return saveStream(stream_p)


  ###*
  # Get local stream
  # @method stream
  # @param {String} [name='stream'] Name of the stream
  # @return {Promise -> rtc.Stream} Promise of the stream
  ###
  stream: (name=@DEFAULT_STREAM) ->
    return @streams[name]
