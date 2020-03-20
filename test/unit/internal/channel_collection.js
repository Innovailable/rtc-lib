/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {run_permutations} = require('../../test_helper');

const {
  ChannelCollection
} = require('../../../src/internal/channel_collection');

class TestChannel {
  constructor(_label) {
    this._label = _label;
  }
  label() { return this._label; }
}

const channel_a = new TestChannel('a');
const channel_b = new TestChannel('b');
const channel_c = new TestChannel('c');


describe('ChannelCollection', function() {
  let coll = null;

  describe('Adding one channel', function() {
    beforeEach(() => coll = new ChannelCollection());

    const get_actions = get => ({
      setRemote() { return coll.setRemote({a: 1}); },
      setLocal() { return coll.setLocal({a: 1}); },
      resolve() { return coll.resolve(channel_a); },
      get
    });

    run_permutations("resolve channel", get_actions(done => coll.get('a').should.eventually.be.equal(channel_a).notify(done)));
    return run_permutations("reject other", get_actions(done => coll.get('other').should.be.rejectedWith(Error).notify(done)));
  });


  describe('Adding mutliple channels', function() {
    before(function() {
      coll = new ChannelCollection();
      coll.setRemote({a: 1, b: 1});
      coll.setLocal({a: 1, b: 1});
      coll.resolve(channel_a);
      coll.resolve(channel_b);
      return coll.resolve(channel_c);
    });

    it('should get existing channel a', () => coll.get('a').should.eventually.be.equal(channel_a));

    it('should get existing channel b', () => coll.get('b').should.eventually.be.equal(channel_b));

    it('should reject unnegotiated channel c', () => coll.get('c').should.be.rejectedWith(Error));

    return it('should reject unknown channel d', () => coll.get('d').should.be.rejectedWith(Error));
  });


  return describe('Adding different channels on remote and local', function() {
    before(function() {
      coll = new ChannelCollection();
      coll.setRemote({a: 1, b: 1});
      coll.setLocal({b: 1, c: 1});
      coll.resolve(channel_a);
      coll.resolve(channel_b);
      return coll.resolve(channel_c);
    });

    it('should reject remote channel a', () => coll.get('a').should.be.rejectedWith(Error));

    it('should get common channel b', () => coll.get('b').should.eventually.be.equal(channel_b));

    return it('should reject local channel c', () => coll.get('c').should.be.rejectedWith(Error));
  });
});
