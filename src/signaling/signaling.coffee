{EventEmitter} = require('events')

###*
# @module rtc.signaling
###

###*
# Concept of a class implementing signaling. Might use a `rtc.signaling.Channel` to abstract the connection to the server.
#
# You do not have to extend this claass, just implement the functionality.
#
# @extends events.EventEmitter
# @class rtc.signaling.Signaling
###
class exports.Signaling extends EventEmitter

  ###*
  # A new peer joined the room
  # @event peer_joined
  # @param {rtc.signaling.SignalingPeer} peer The new peer
  ###

  ###*
  # The connection to the signaling server was closed
  # @event closed
  ###

  ###*
  # Establishes the connection with the signaling server
  # @method connect
  # @return {Promise} Promise which is resolved when the connection is established
  ###
  connect: () -> throw new Error("Not implemented")

  ###*
  # Closes the connection to the signaling server
  # @method close
  ###
  close: () -> throw new Error("Not implemented")


###*
# Concept of a class implementing a signaling connection to a peer.
#
# You do not have to extend this class, just implement the functionality.
#
# @extends events.EventEmitter
# @class rtc.signaling.SignalingPeer
###
class exports.SignalingPeer extends EventEmitter

  ###*
  # The remote peer left the room
  # @event left
  ###

  ###*
  # Received a message from the remote peer
  # @event message
  # @param {String} event ID of the event
  # @param {Obejct} data Payload of the event
  ###

  ###*
  # The status object of the remote peer was updated
  # @event new_status
  # @param {Object} status The new status
  ###

  ###*
  # The status object of the remote peer
  # @property status
  # @type Object
  # @readonly
  ###

  ###*
  # Whether the local user was in the room before the remote user (used to determine which peer will initiate the connection)
  # @property first
  # @type Boolean
  # @readonly
  ###

  ###*
  # Sends the event with the given payload to the remote peer
  # @method send
  # @param {String} event The id of the event
  # @param {Object} data The payload of the event
  # @return {Promise} Promise which will be resolved once the message is sent
  ###
  send: (event, data={}) -> throw new Error("Not implemented")


###*
# Concept of a class implementing a signaling channel. Might be used by signaling implementations to connect to a signaling server.
#
# You do not have to extend this class, just implement the functionality.
#
# @extends events.EventEmitter
# @class rtc.signaling.Channel
###
class exports.Channel extends EventEmitter

  ###*
  # A message was received from the signaling server
  # @event message
  # @param {Object} msg The received message
  ###

  ###*
  # The connection to the signaling server was closed
  # @event closed
  ###

  ###*
  # Establishes the connection with the signaling server
  # @method connect
  # @return {Promise} Promise which is resolved when the connection is established
  ###
  connect: () -> throw new Error("Not implemented")

  ###*
  # Sends a message to the signaling server
  # @method send
  # @param {Object} msg The message to send
  # @return {Promise} Promise which is resolved when the message is sent
  ###
  send: (msg) -> throw new Error("Not implemented")

  ###*
  # Closes the connection to the signaling server
  # @method close
  ###
  close: () -> throw new Error("Not implemented")
