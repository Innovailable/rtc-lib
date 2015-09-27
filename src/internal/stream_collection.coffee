Deferred = require('es6-deferred')
EventEmitter = require('events').EventEmitter

# Helper handling the mapping of streams for RemotePeer
#
# @private
#
class exports.StreamCollection extends EventEmitter

  
  # Constructs a StreamCollection
  #
  # @property streams
  #
  constructor: () ->
    @streams = {}

    @_defers = {}
    @_waiting = {}
    @_pending = {}

    @wait_d = new Deferred()
    @wait_p = @wait_d.promise


  # 
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


  get: (name) ->
    @wait_p.then () =>
      if @streams[name]?
        return @streams[name]
      else
        throw new Error("Stream not offered")

