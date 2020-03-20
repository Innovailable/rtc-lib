/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {LocalPeer} = require('../../src/local_peer');
const {Stream} = require('../../src/stream');


describe('LocalPeer', function() {
  let test_lp = null;
  beforeEach(() => test_lp = new LocalPeer());

  describe('channels', function() {
    it('should contain Channel-Object with correct key after addDataChannel', function() {
      test_lp.addDataChannel('test-Channel');
      return test_lp.channels.should.contain.keys('test-Channel');
    });
    return it('should contain Channel-Object with correct key and description after addDataChannel', function() {
      test_lp.addDataChannel('test-Channel', {"a": "test_desc"});
      return test_lp.channels.should.deep.equal({"test-Channel": {"a": "test_desc"}});
    });
  });

  describe('stream', () => it('should return the the added stream', function() {
    const test_stream = new Stream("test_stream");
    test_lp.addStream('tst', test_stream);
    return test_lp.stream('tst').should.eventually.equal(test_stream);
  }));

  describe('streams', () => it('should contain local stream with correct name', function() {
    const test_stream = new Stream("test_stream");
    test_lp.addStream('tst', test_stream);
    return test_lp.streams["tst"].should.eventually.equal(test_stream);
  }));

  return describe('status', function() {
    it('should contain the Test-Object at the correct key', function() {
      const test_object = {a: "b"};
      test_lp.status("t", test_object);
      return test_lp.status("t").should.equal(test_object);
    });
    return it('should contain all added Test-Objects at the correct keys', function() {
      const test_object_1 = {a: "b"};
      const test_object_2 = {c: "d"};
      test_lp.status("t_1", test_object_1);
      test_lp.status("t_2", test_object_2);
      test_lp.status("t_1").should.equal(test_object_1);
      return test_lp.status("t_2").should.equal(test_object_2);
    });
  });
});

