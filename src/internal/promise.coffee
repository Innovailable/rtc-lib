###*
# Alias for native promises or a polyfill if not supported
# @module rtc.internal
# @class rtc.internal.Promise
###
exports.Promise = global.Promise || require('es6-promise').Promise

###*
# Helper to implement deferred execution with promises
# @module rtc.internal
# @class rtc.internal.Deferred
###
###*
# Resolves the promise
# @method resolve
###
###*
# Reject the promise
# @method reject
###
###*
# The promise which will get resolved or rejected by this deferred
# @property promise
###
class exports.Deferred

  constructor: () ->
    @promise = new exports.Promise (resolve, reject) =>
      @resolve = resolve
      @reject = reject
