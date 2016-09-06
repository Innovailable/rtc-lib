###############################################################################
#
# This file is part of rtc-lib.
#
# rtc-lib is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# rtc-lib is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# rtc-lib.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################


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

