exports.Promise = Promise = global.Promise || require('es6-promise').Promise

class exports.Deferred

  constructor: () ->
    @promise = new Promise (resolve, reject) =>
      @resolve = resolve
      @reject = reject
