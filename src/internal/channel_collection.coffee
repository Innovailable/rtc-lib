Deferred = require('es6-deferred')
Promise = require('es6-promise').Promise

# TODO: does not remove channels known before ...

class exports.ChannelCollection

  constructor: (@channels={}) ->
    @defers = {}
    @pending = {}

    @wait_d = new Deferred()
    @wait_p = @wait_d.promise


  setLocal: (data) ->
    @local = data

    if @remote?
      @update()


  setRemote: (data) ->
    @remote = data

    if @local?
      @update()


  update: () ->
    # create channel promises
    # TODO: warn if config differs

    for name, config of @remote
      if @local[name]?
        if @channels[name]?
          # nothing to do

        else if @pending[name]?
          # use the pending channel

          channel = @pending[name]
          delete @pending[name]

          @channels[name] = Promise.resolve(channel)

        else
          # create a defer for the channel

          defer = new Deferred()

          @channels[name] = defer.promise
          @defers[name] = defer

      else
        # TODO: better warning
        console.log("DataChannel offered by remote but not by local")

    # notice @local only channels

    for name of @local
      if not @remote[name]?
        console.log("DataChannel offered by local but not by remote")

    # we should be able to get channels from now on

    @wait_d.resolve()


  resolve: (channel) ->
    label = channel.label()

    if @defers[label]?
      @defers[label].resolve(channel)
      delete @defers[label]
    else
      @pending[label] = channel


  get: (name) ->
    @wait_p.then () =>
      if @channels[name]?
        return @channels[name]
      else
        throw new Error("DataChannel not negotiated")
