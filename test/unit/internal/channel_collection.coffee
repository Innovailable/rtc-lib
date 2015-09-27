{run_permutations} = require('../../test_helper')

ChannelCollection = require('../../../src/internal/channel_collection').ChannelCollection

class TestChannel
  constructor: (@_label) ->
  label: () -> @_label

channel_a = new TestChannel('a')
channel_b = new TestChannel('b')
channel_c = new TestChannel('c')


describe 'ChannelCollection', () ->
  coll = null

  describe 'Adding one channel', () ->
    beforeEach () -> coll = new ChannelCollection()

    get_actions = (get) -> {
      setRemote: () -> coll.setRemote({a: 1})
      setLocal: () -> coll.setLocal({a: 1})
      resolve: () -> coll.resolve(channel_a)
      get: get
    }

    run_permutations("resolve channel", get_actions (done) -> coll.get('a').should.eventually.be.equal(channel_a).notify(done))
    run_permutations("reject other", get_actions (done) -> coll.get('other').should.be.rejectedWith(Error).notify(done))


  describe 'Adding mutliple channels', () ->
    before () ->
      coll = new ChannelCollection()
      coll.setRemote({a: 1, b: 1})
      coll.setLocal({a: 1, b: 1})
      coll.resolve(channel_a)
      coll.resolve(channel_b)

    it 'should get existing channel a', () ->
      return coll.get('a').should.eventually.be.equal(channel_a)

    it 'should get existing channel b', () ->
      return coll.get('b').should.eventually.be.equal(channel_b)

    it 'should reject missing channel c', () ->
      return coll.get('c').should.be.rejectedWith(Error)


  describe 'Adding different channels on remote and local', () ->
    before () ->
      coll = new ChannelCollection()
      coll.setRemote({a: 1, b: 1})
      coll.setLocal({b: 1, c: 1})
      coll.resolve(channel_a)
      coll.resolve(channel_b)
      coll.resolve(channel_c)

    it 'should reject remote channel a', () ->
      return coll.get('a').should.be.rejectedWith(Error)

    it 'should get common channel b', () ->
      return coll.get('b').should.eventually.be.equal(channel_b)

    it 'should reject local channel c', () ->
      return coll.get('c').should.be.rejectedWith(Error)
