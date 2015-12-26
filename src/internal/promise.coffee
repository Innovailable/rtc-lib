###*
# @module rtc.internal
###

###*
# Alias for native promises or a polyfill if not supported
# @class rtc.internal.Promise
###
exports.Promise = global.Promise || require('es6-promise').Promise

###*
# Helper to implement deferred execution with promises
# @class rtc.internal.Deferred
###
###*
# Resolves the promise
# @method resolve
# @param [data] The payload to which the promise will resolve
#
# @example
#     var defer = new Deferred()
#     defer.resolve(42);
#     defer.promise.then(function(res) {
#       console.log(res);   // 42
#     }
###
###*
# Reject the promise
# @method reject
# @param {Error} error The payload to which the promise will resolve
#
# @example
#     var defer = new Deferred()
#     defer.reject(new Error("Reject because we can!"));
#     defer.promise.then(function(data) {
#       // wont happen
#     }).catch(function(err) {
#       // will happen
#     }
###
###*
# The promise which will get resolved or rejected by this deferred
# @property {Promise} promise
###
class exports.Deferred

  constructor: () ->
    @promise = new exports.Promise (resolve, reject) =>
      @resolve = resolve
      @reject = reject


###*
# Adds a timeout to a promise. The promise will be rejected if timeout is
# reached. It will act like the underlying promise if it is resolved or
# rejected before the timeout is reached.
# @param {Promse} promise The underlying promise
# @param {number} time Timeout in ms
# @return {Promise} Promise acting like the underlying promise or timeout
###
exports.timeout = (promise, time) ->
  new Promise (resolve, reject) ->
    promise.then(resolve, reject)
    setTimeout () ->
      reject(new Error('Operation timed out'))
    , time
