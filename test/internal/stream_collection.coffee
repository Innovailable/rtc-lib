StreamCollection = require('../../src/internal/stream_collection.coffee').StreamCollection

class TestStream
  constructor: (@_id) ->
  id: () -> @_id

stream = new TestStream("1234")
stream2 = new TestStream("5678")

describe 'StreamCollection', () ->
  describe 'Adding one stream', ->
    it 'should get stream after update and resolve', () ->
      coll = new StreamCollection()

      coll.update({stream: stream.id()})
      coll.resolve(stream)

      return coll.get("stream").should.become(stream)

    it 'should get stream before update and resolve', () ->
      coll = new StreamCollection()

      promise = coll.get("stream").should.become(stream)

      coll.update({stream: stream.id()})
      coll.resolve(stream)

      return promise

    it 'should get stream between update and resolve', () ->
      coll = new StreamCollection()

      coll.update({stream: stream.id()})

      promise = coll.get("stream").should.become(stream)

      coll.resolve(stream)

      return promise

    it 'should reject other stream after update and resolve', () ->
      coll = new StreamCollection()

      coll.update({stream: stream.id()})
      coll.resolve(stream)

      return coll.get("other").should.be.rejectedWith(Error)

    it 'should reject other stream before update and resolve', () ->
      coll = new StreamCollection()

      promise = coll.get("other").should.be.rejectedWith(Error)

      coll.update({stream: stream.id()})
      coll.resolve(stream)

      return promise

    it 'should reject other stream between update and resolve', () ->
      coll = new StreamCollection()

      coll.update({stream: stream.id()})

      promise = coll.get("other").should.be.rejectedWith(Error)

      coll.resolve(stream)

      return promise

  describe 'Adding two streams', ->
    coll = null

    before =>
      coll = new StreamCollection()
      coll.update({a: stream.id(), b: stream2.id()})
      coll.resolve(stream)
      coll.resolve(stream2)

    it 'should get stream a', () ->
      return coll.get('a').should.become(stream)

    it 'should get stream b', () ->
      return coll.get('b').should.become(stream2)

    it 'should reject stream c', () ->
      return coll.get('c').should.be.rejectedWith(Error)

