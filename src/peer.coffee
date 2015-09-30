EventEmitter = require('events').EventEmitter

###*
# A user in the room
# @class rtc.Peer
###
class exports.Peer extends EventEmitter

  ###*
  # The status of the peer has changed
  # @event status_changed
  # @param {String} key Key of the changed stats
  # @param value Value of the changed status
  ###

  # default names
  DEFAULT_CHANNEL: 'data'
  DEFAULT_STREAM: 'stream'


  ###*
  # Get a value of the status object
  # @method status
  # @param {String} key The key 
  # @return The value
  ###
  status: (key) -> throw new Error("Not implemented")
