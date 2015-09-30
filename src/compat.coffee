###*
# Core functionality
# @module rtc
# @main rtc
###
###*
# Signaling and signaling channels
# @module rtc.signaling
# @main rtc.signaling
###
###*
# Internal helpers
# @module rtc.internal
# @main rtc.internal
###

bindHelper = (obj, fun) ->
  if not fun?
    return

  return fun.bind(obj)

exports.compat = compat = {
  PeerConnection: window.PeerConnection || window.webkitPeerConnection00 || window.webkitRTCPeerConnection || window.mozRTCPeerConnection
  IceCandidate: window.RTCIceCandidate || window.mozRTCIceCandidate
  SessionDescription: window.mozRTCSessionDescription || window.RTCSessionDescription
  MediaStream: window.MediaStream || window.mozMediaStream || window.webkitMediaStream
  getUserMedia: bindHelper(navigator, navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia)

  supported: () ->
    return compat.PeerConnection? and compat.IceCandidate? and compat.SessionDescription? and compat.getUserMedia?
}

