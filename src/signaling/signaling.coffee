###*
# Concept of a class implementing signaling. Might use a `rtc.signaling.Channel` to abstract the connection to the server.
#
# You do not have to extend this claass, just implement the functionality.
#
# @module rtc.signaling
# @class rtc.signaling.Signaling
###
class exports.Signaling

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
# @module rtc.signaling
# @class rtc.signaling.SignalingPeer
###
class exports.SignalingPeer


###*
# Concept of a class implementing a signaling channel. Might be used by signaling implementations to connect to a signaling server.
#
# You do not have to extend this class, just implement the functionality.
#
# @module rtc.signaling
# @class rtc.signaling.Channel
###
class exports.Channel

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
