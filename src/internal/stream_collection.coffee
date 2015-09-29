Deferred = require('es6-deferred')
EventEmitter = require('events').EventEmitter

###*
# Helper handling the mapping of streams for RemotePeer
# @class rtc.internal.StreamCollection
#
# @constructor
###
class exports.StreamCollection extends EventEmitter

  ###*
  # A new stream was added to the collection
  # @event steam_added
  # @param {String} name The user defined name of the stream
  # @param {Promise -> rtc.Stream} stream Promise to the stream
  ###

  constructor: () ->
    ###*
    # Contains the promises which will resolve to the streams
    # @property {Object} streams
    ###
    @streams = {}

    @_defers = {}
    @_waiting = {}
    @_pending = {}

    @wait_d = new Deferred()
    @wait_p = @wait_d.promise


  ###*
  # Set stream description and generate promises
  # @method update
  # @param data {Object} An object mapping the stream ids to stream names
  ###
  update: (data) ->
    members = []
    @_waiting = {}

    # remove old streams

    for name, stream_p in @streams
      if not data[name]?
        # remove

        delete @streams[name]
        @emit('stream_removed', name)

        # close/fail

        # TODO: this does not work anymore ...
        if stream_p.isFullfilled()
          stream_p.then (stream) ->
            stream.close()
        else if stream_p.isPending()
          stream_p.reject(new Error("Stream removed before being established"))

    # update mappings

    for name, id of data
      # does stream exist?

      if not @streams[name]?
        # create stream promise

        defer = new Deferred()

        @streams[name] = defer.promise
        @_defers[name] = defer

        @emit('stream_added', name, defer.promise)

      # do we adjust stream initialization?

      if @_defers[name]?
        if @_pending[id]?
          # got it!

          stream = @_pending[id]
          delete @_pending[id]

          @_defers[name].resolve(stream)
          delete @_defers[name]

        else
          # add waiting mapping

          @_waiting[id] = name

    @wait_d.resolve()


  ###*
  # Add stream to the collection and resolve promises waiting for it
  # @method resolve
  # @param {rtc.Stream} stream
  ###
  resolve: (stream) ->
    id = stream.id()

    if @_waiting[id]?
      # stream is expected

      name = @_waiting[id]
      delete @_waiting[id]

      @_defers[name].resolve(stream)
      delete @_defers[name]

    else
      # lets hope someone wants this later ...

      @_pending[id] = stream


  ###*
  # Gets a promise for a stream with the given name. Might be rejected after `update()`
  #
  # @method get
  # @param {String} name
  # @return {Promise} The promise for the `rtc.Stream`
  ###
  get: (name) ->
    @wait_p.then () =>
      if @streams[name]?
        return @streams[name]
      else
        throw new Error("Stream not offered")

