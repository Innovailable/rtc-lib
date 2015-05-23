events = require('events')

class exports.Peer extends events.EventEmitter

  # default names
  @DEFAULT_CHANNEL: 'data'
  @DEFAULT_STREAM: 'stream'
