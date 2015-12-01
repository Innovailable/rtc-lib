EventEmitter = require('events').EventEmitter

###*
# @module rtc
###
###*
# A user in the room
# @class rtc.Peer
###
class exports.Peer extends EventEmitter

  ###*
  # The status of the peer has changed
  # @event status_changed
  # @param {Object} status The new status object
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
