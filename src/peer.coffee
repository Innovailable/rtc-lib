events = require('events')

class Peer extends events.EventEmitter

  # default names
  @DEFAULT_CHANNEL: 'data'
  @DEFAULT_STREAM: 'stream'


exports.Peer = Peer
