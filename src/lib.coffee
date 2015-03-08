extend = (obj) ->
  for key, value of obj
    exports[key] = value

  return exports

extend(require('./remote_peer'))
extend(require('./local_peer'))
extend(require('./stream'))
extend(require('./compat'))
extend(require('./media'))
