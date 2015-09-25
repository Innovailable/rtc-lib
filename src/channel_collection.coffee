q = require('q')

# TODO: does not remove channels known before ...

class exports.ChannelCollection

  constructor: (@channels={}) ->
    @defers = {}
    @pending = {}


  update: (local, remote) ->
    console.log("update channels")
    console.log(local)
    console.log(remote)
    # create channel promises
    # TODO: warn if config differs

    for name, config of remote
      if local[name]?
        if @channels[name]?
          # nothing to do

        else if @pending[name]?
          # use the pinding channel

          channel = @pending[name]
          delete @pending[name]

          @channels[name] = q(channel)

        else
          # create a defer for the channel

          defer = q.defer()

          @channels[name] = defer.promise
          @defers[name] = defer

      else
        # TODO: better warning
        console.log("DataChannel offered by remote but not by local")

    # notice local only channels

    for name of local
      if not remote[name]?
        console.log("DataChannel offered by local but not by remote")


  resolve: (channel) ->
    label = channel.label()

    if @defers[label]?
      @defers[label].resolve(channel)
      delete @defers[label]
    else
      @pending[label] = channel
