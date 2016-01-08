extend = (root, obj) ->
  for key, value of obj
    root[key] = value

  return exports

module.exports = exports = {
  internal: {}
  signaling: {}
}

extend(exports, require('./peer'))
extend(exports, require('./remote_peer'))
extend(exports, require('./local_peer'))
extend(exports, require('./peer_connection'))
extend(exports, require('./stream'))
extend(exports, require('./compat'))
extend(exports, require('./room'))
extend(exports, require('./video_element'))

extend(exports.internal, require('./internal/stream_collection'))
extend(exports.internal, require('./internal/channel_collection'))
extend(exports.internal, require('./internal/promise'))

extend(exports.signaling, require('./signaling/web_socket_channel'))
extend(exports.signaling, require('./signaling/palava_signaling'))
extend(exports.signaling, require('./signaling/calling_signaling'))
extend(exports.signaling, require('./signaling/muc_signaling'))

