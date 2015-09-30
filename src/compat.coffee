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
  Promise: window.Promise || require('es6-promise').Promise

  supported: () ->
    return compat.PeerConnection? and compat.IceCandidate? and compat.SessionDescription? and compat.getUserMedia?
}

