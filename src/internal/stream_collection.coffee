q = require('q')
EventEmitter = require('events').EventEmitter

class exports.StreamCollection extends EventEmitter

  constructor: (@streams={}) ->
    @defers = {}
    @waiting = {}
    @pending = {}

    @wait_d = q.defer()
    @wait_p = @wait_d.promise


  update: (data) ->
    members = []
    @waiting = {}

    # remove old streams

    for name, stream_p in @streams
      if not data[name]?
        # remove

        delete @streams[name]
        @emit('stream_removed', name)

        # close/fail

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

        defer = q.defer()

        @streams[name] = defer.promise
        @defers[name] = defer

        @emit('stream_added', name, defer.promise)

      # do we adjust stream initialization?

      if @defers[name]?
        if @pending[id]?
          # got it!

          stream = @pending[id]
          delete @pending[id]

          @defers[name].resolve(stream)
          delete @defers[name]

        else
          # add waiting mapping

          @waiting[id] = name

    @wait_d.resolve()


  resolve: (stream) ->
    id = stream.id()

    if @waiting[id]?
      # stream is expected

      name = @waiting[id]
      delete @waiting[id]

      @defers[name].resolve(stream)
      delete @defers[name]

    else
      # lets hope someone wants this later ...

      @pending[id] = stream


  get: (name) ->
    @wait_p.then () =>
      if @streams[name]?
        return @streams[name]
      else
        throw new Error("Stream not offered")

