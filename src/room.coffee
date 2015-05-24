EventEmitter = require('events').EventEmitter


class exports.Room extends EventEmitter

  constructor: (@name, @signaling, @local, @options) ->
    @peers = {}


  join: () ->
    return @signaling.join(@name)


  leave: () ->
    return @signaling.leave()


  destroy: () ->
    # TODO ...
    return @signaling.leave()
