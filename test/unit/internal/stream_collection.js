/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {run_permutations} = require('../../test_helper');

const {
  StreamCollection
} = require('../../../src/internal/stream_collection');

class TestStream {
  constructor(_id) {
    this._id = _id;
  }
  id() { return this._id; }
}

const stream = new TestStream("1234");
const stream2 = new TestStream("5678");


describe('StreamCollection', function() {
  describe('Adding one stream', function() {
    let coll = null;

    beforeEach(() => coll = new StreamCollection());

    const get_actions = get => ({
      update() { return coll.update({stream: stream.id()}); },
      resolve() { return coll.resolve(stream); },
      get
    });

    run_permutations("resolve stream", get_actions(done => coll.get("stream").should.eventually.be.equal(stream).notify(done)));
    return run_permutations("reject other", get_actions(done => coll.get("other").should.be.rejectedWith(Error).notify(done)));
  });


  return describe('Adding two streams', function() {
    let coll = null;

    before(function() {
      coll = new StreamCollection();
      coll.update({a: stream.id(), b: stream2.id()});
      coll.resolve(stream);
      return coll.resolve(stream2);
    });

    it('should resolve existing stream a', () => coll.get('a').should.eventually.be.equal(stream));

    it('should resolve existing stream b', () => coll.get('b').should.eventually.be.equal(stream2));

    return it('should reject missing stream c', () => coll.get('c').should.be.rejectedWith(Error));
  });
});

