/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {Deferred} = require('../../src/internal/promise');

describe('deferred', function() {

  let test_defer = null;
  beforeEach(() => test_defer =  new Deferred());

  // reject
  it('should reject the previously rejected promise', function() {
    test_defer.reject(new Error("Rejected"));
    return test_defer.promise.should.be.rejected;
  });
  it('should reject the subsequently rejected promise', function() {
    const rej_p = test_defer.promise.should.be.rejected;
    test_defer.reject(new Error("Rejected"));
    return rej_p;
  });

  // resolve
  it('should resolve the previously resolved promise', function() {
    test_defer.resolve("resolved");
    return test_defer.promise.should.be.fulfilled;
  });
  return it('should resolve the subsequently resolved promise', function() {
    const res_p = test_defer.promise.should.be.fulfilled;
    test_defer.resolve("resolved");
    return res_p;
  });
});