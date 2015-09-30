{Deferred,Promise} = require('./promise')

###*
# Helper which handles DataChannel negotiation for RemotePeer
# @class rtc.internal.ChannelCollection
###
class exports.ChannelCollection

  constructor: () ->
    @channels = {}

    @defers = {}
    @pending = {}

    @wait_d = new Deferred()
    @wait_p = @wait_d.promise


  ###*
  # Set the local channel description.
  # @method setLocal
  # @param {Object} data Object describing each offered DataChannel
  ###
  setLocal: (data) ->
    @local = data

    if @remote?
      @_update()


  ###*
  # Set the remote channel description.
  # @method setRemote
  # @param {Object} data Object describing each offered DataChannel
  ###
  setRemote: (data) ->
    @remote = data

    if @local?
      @_update()


  ###*
  # Matches remote and local descriptions and creates promises common DataChannels
  # @method _update
  # @private
  ###
  _update: () ->
    # create channel promises
    # TODO: warn if config differs

    for name, config of @remote
      if @local[name]?
        if @channels[name]?
          # nothing to do
          # should currently not happen

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


  ###*
  # Resolves promises waiting for the given DataChannel
  # @method resolve
  # @param {DataChannel} channel The new channel
  ###
  resolve: (channel) ->
    label = channel.label()

    if @defers[label]?
      @defers[label].resolve(channel)
      delete @defers[label]
    else
      @pending[label] = channel


  ###*
  # Get a promise to a DataChannel. Will resolve if DataChannel was offered and gets initiated. Might reject after remote and local description are processed.
  # @method get
  # @param {String} name The label of the channel to get
  # @return {Promise -> DataChannel} Promise for the DataChannel
  ###
  get: (name) ->
    @wait_p.then () =>
      if @channels[name]?
        return @channels[name]
      else
        throw new Error("DataChannel not negotiated")
