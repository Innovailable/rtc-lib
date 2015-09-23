EventEmitter = require('events').EventEmitter


class exports.Peer extends EventEmitter

  # default names
  DEFAULT_CHANNEL: 'data'
  DEFAULT_STREAM: 'stream'


  stream: (name=@DEFAULT_STREAM) ->
    return @streams[name]
