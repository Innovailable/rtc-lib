{LocalPeer} = require('../../src/local_peer')
{Stream} = require('../../src/stream')


describe 'LocalPeer', () ->
  test_lp = null
  beforeEach () ->
    test_lp = new LocalPeer()

  describe 'channels', () ->
    it 'should contain Channel-Object with correct key after addDataChannel', () ->
      test_lp.addDataChannel('test-Channel')
      test_lp.channels.should.contain.keys('test-Channel')
    it 'should contain Channel-Object with correct key and description after addDataChannel', () ->
      test_lp.addDataChannel('test-Channel', {"a": "test_desc"})
      test_lp.channels.should.deep.equal({"test-Channel": {"a": "test_desc"}})

  describe 'stream', () ->
    it 'should return the the added stream', () ->
      test_stream = new Stream("test_stream")
      test_lp.addStream('tst', test_stream)
      return test_lp.stream('tst').should.eventually.equal(test_stream)

  describe 'streams', () ->
    it 'should contain local stream with correct name', () ->
      test_stream = new Stream("test_stream")
      test_lp.addStream('tst', test_stream)
      return test_lp.streams["tst"].should.eventually.equal(test_stream)

  describe 'status', () ->
    it 'should contain the Test-Object at the correct key', () ->
      test_object = {a: "b"}
      test_lp.status("t", test_object)
      test_lp.status("t").should.equal(test_object)
    it 'should contain all added Test-Objects at the correct keys', () ->
      test_object_1 = {a: "b"}
      test_object_2 = {c: "d"}
      test_lp.status("t_1", test_object_1)
      test_lp.status("t_2", test_object_2)
      test_lp.status("t_1").should.equal(test_object_1)
      test_lp.status("t_2").should.equal(test_object_2)

