{Deferred} = require('../../src/internal/promise')

describe 'deferred', () ->

  test_defer = null
  beforeEach () ->
    test_defer =  new Deferred()

  # reject
  it 'should reject the previously rejected promise', () ->
    test_defer.reject(new Error("Rejected"))
    return test_defer.promise.should.be.rejected
  it 'should reject the subsequently rejected promise', () ->
    rej_p = test_defer.promise.should.be.rejected
    test_defer.reject(new Error("Rejected"))
    return rej_p

  # resolve
  it 'should resolve the previously resolved promise', () ->
    test_defer.resolve("resolved")
    return test_defer.promise.should.be.fulfilled
  it 'should resolve the subsequently resolved promise', () ->
    res_p = test_defer.promise.should.be.fulfilled
    test_defer.resolve("resolved")
    return res_p