/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {Calling, CallingNamespace, CallingUser, CallingRoom, CallingPeer, CallingInInvitation, CallingOutInvitation} = require('../../../src/signaling/calling_signaling');
const {EventEmitter} = require('events');
const {Deferred} = require('../../../src/internal/promise');

const msg_compare = function(msg, cmp) {
  cmp.tid = msg.tid;
  return msg.should.deep.equal(cmp);
};

class TestChannel extends EventEmitter {

  constructor() {
      super();
    this.sent = [];
    this.connect_d = new Deferred();
  }

  connect() {
    return this.connect_d.promise;
  }

  answer(data, num) {
    if (num == null) { num = 0; }
    return this.receive({
      type: 'answer',
      tid: this.sent[num].tid,
      data
    });
  }

  answerError(error, num) {
    if (num == null) { num = 0; }
    return this.receive({
      type: 'answer',
      tid: this.sent[num].tid,
      error
    });
  }

  receive(msg) {
    return this.emit('message', msg);
  }

  send(msg) {
    return this.sent.push(msg);
  }
}


describe('CallingSignaling', function() {
  let channel = null;
  let calling = null;

  beforeEach(function() {
    channel = new TestChannel();
    return calling = new Calling(channel);
  });

  describe('Calling', function() {

    describe('request', function() {

      it('should use unique numeric transactions ids', function() {
        calling.request({type: 'test'});
        calling.request({type: 'test'});

        channel.sent[0].tid.should.be.a('number');
        channel.sent[1].tid.should.be.a('number');
        return channel.sent[0].tid.should.not.equal(channel.sent[1].tid);
      });


      it('should call answer callback with data', function(done) {
        calling.request({type: 'test'}, function(err, data) {
          data.should.equal(42);
          return done();
        });

        return channel.answer(42);
      });


      it('should call answer callback with error', function(done) {
        calling.request({type: 'test'}, function(err, data) {
          err.message.should.equal('Error');
          return done();
        });

        return channel.answerError('Error');
      });


      it('should resolve promise with data', function() {
        const promise = calling.request({type: 'test'});

        channel.answer(42);

        return promise.should.become(42);
      });


      it('should reject promise with error', function() {
        const promise = calling.request({type: 'test'});

        channel.answerError('Error');

        return promise.should.be.rejectedWith('Error');
      });


      it('should handle answers with different order', function() {
        const a = calling.request({type: 'test'});
        const b = calling.request({type: 'test'});
        const c = calling.request({type: 'test'});

        channel.answer('b', 1);
        channel.answer('c', 2);
        channel.answer('a', 0);

        return Promise.all([
          a.should.become('a'),
          b.should.become('b'),
          c.should.become('c')
        ]);
      });


      return it('should clean up answer handlers after resolving them', function() {
        const p = calling.request({type: 'test'});
        channel.answer(42);

        return p.then(res => calling.answers.should.be.empty);
      });
    });


    describe('connect', function() {

      it('should reject when channel connect rejects', function() {
        channel.connect_d.reject(new Error('Error'));
        return calling.connect().should.be.rejected;
      });


      it('should resolve connect promise on hello', function() {
        const p = calling.connect();
        channel.connect_d.resolve();
        channel.receive({type: 'hello'});
        return p;
      });


      it('should get id from hello', function() {
        const p = calling.connect();
        channel.connect_d.resolve();

        channel.receive({
          type: 'hello',
          id: 42
        });

        return p.then(() => calling.id.should.equal(42));
      });

      return it('should emit `closed` when channel closes');
    });

    describe('register', function() {

      it('should send register command', function() {
        const promise = calling.register('test');

        msg_compare(channel.sent[0], {
          type: 'ns_user_register',
          namespace: 'test'
        });

        channel.answer();
        return promise;
      });


      return it('should send unregister command', function() {
        const promise = calling.unregister('test');

        msg_compare(channel.sent[0], {
          type: 'ns_user_unregister',
          namespace: 'test'
        });

        channel.answer();
        return promise;
      });
    });


    describe('subscribe', function() {

      it('should send subscribe command', function() {
        calling.subscribe('test');

        return msg_compare(channel.sent[0], {
          type: 'ns_subscribe',
          namespace: 'test'
        });
      });


      return it('should create namespace from answer', function() {
        const promise = calling.subscribe('test');

        channel.answer({a: {}});

        return promise.then(function(namespace) {
          namespace.id.should.equal('test');
          return namespace.users.should.have.key('a');
        });
      });
    });


    describe('join', () => it('should send join command on connect on room', function() {
      const room = calling.room('test');
      const promise = room.connect();

      msg_compare(channel.sent[0], {
        type: 'room_join',
        room: 'test',
        status: {}
      });

      channel.answer({
        room: 'test',
        peers: {},
        status: {a: 'b'}
      });

      return promise.then(function() {
        room.id.should.equal('test');
        return room.status.should.deep.equal({a: 'b'});
      });
    }));


    describe('status', () => it('should send status command', function() {
      calling.setStatus({a: 'b'});

      return msg_compare(channel.sent[0], {
        type: 'status',
        status: {a: 'b'}
      });
    }));


    return describe('invitation', () => it('should throw event on incoming invitation', function(done) {
      calling.on('invitation', function(inv) {
        inv.handle.should.equal(42);
        inv.user.should.equal('1234');
        inv.status.should.deep.equal({a: 'b'});
        inv.data.should.deep.equal({c: 'd'});
        return done();
      });

      return channel.receive({
        type: 'invite_incoming',
        handle: 42,
        user: "1234",
        status: {a: 'b'},
        data: {c: 'd'}
      });
    }));
  });


  describe('Namespace', function() {
  const get_namespace = function(users={}, rooms={}) {
      const promise = calling.subscribe('test');
      channel.answer({ users, rooms });
      // reset sent messages
      channel.sent.length = 0;
      return promise;
    };

    it('should contain initial users', () => {
        get_namespace({a: {}, b: {c: 'd'}}).then(function(namespace) {
          namespace.users.should.have.keys('a', 'b');
          return namespace.users['b'].status.should.deep.equal({c: 'd'});
        });
    });


    it('should send unsubscribe message', () => get_namespace().then(function(namespace) {
      const p = namespace.unsubscribe();

      msg_compare(channel.sent[0], {
        type: 'ns_unsubscribe',
        namespace: 'test'
      });

      channel.answer();

      return p;
    }));


    it('should emit `unsubscribed` event when unsubscribed', done => {
        get_namespace().then(function(namespace) {
            namespace.on('unsubscribed', () => done());

            const p = namespace.unsubscribe();

            channel.answer();
    })});


    it('should emit `unsubscribed` when channel is closed');


    it('should emit `user_registered` when user registers', done => get_namespace().then(function(namespace) {
      namespace.on('user_registered', function(user) {
        user.id.should.equal('1234');
        user.status.should.deep.equal({a: 'b'});
        return done();
      });

      return channel.receive({
        type: 'ns_user_add',
        namespace: 'test',
        user: '1234',
        status: {a: 'b'}
      });
    }));


    it('should emit `user_left` when user leaves', done => get_namespace({a: {}}).then(function(namespace) {
      namespace.on('user_left', function(user) {
        user.id.should.equal('a');
        return done();
      });

      return channel.receive({
        type: 'ns_user_rm',
        namespace: 'test',
        user: 'a'
      });
    }));


    it('should emit `left` on user when user leaves', done => get_namespace({a: {}}).then(function(namespace) {
      namespace.users['a'].on('left', () => done());

      return channel.receive({
        type: 'ns_user_rm',
        namespace: 'test',
        user: 'a'
      });
    }));


    it('should emit `left` on user when unsubscribing', done => get_namespace({a: {}}).then(function(namespace) {
      namespace.users['a'].on('left', () => done());

      namespace.unsubscribe();
      return channel.answer();
    }));


    it('should emit `left` on user when channel closes');


    it('should emit `status_changed` on status changes', done => get_namespace({a: {}}).then(function(namespace) {
      const user = namespace.users['a'];

      user.on('status_changed', function(status) {
        status.should.deep.equal({a: 'b'});
        user.status.should.deep.equal({a: 'b'});
        return done();
      });

      return channel.receive({
        type: 'ns_user_update',
        namespace: 'test',
        user: 'a',
        status: {a: 'b'}
      });
    }));


    return it('should remove listeners on channel after unsubscribing', function() {
      channel.listeners('message').length.should.equal(1);

      return get_namespace().then(function(namespace) {
        channel.listeners('message').length.should.equal(2);

        const p = namespace.unsubscribe();
        channel.answer();

        return p;}).then(function() {
        channel.listeners('message').length.should.equal(1);
      });
    });
  });


  describe('Room', function() {

    const get_room = function(peers, status) {
      if (peers == null) { peers = {}; }
      if (status == null) { status = {}; }
      const room = calling.room('test');
      const promise = room.connect();

      channel.answer({
        room: 'test',
        peers,
        status
      });

      // reset sent messages
      channel.sent.length = 0;

      return promise.then(() => room);
    };


    it('should contain initial peers', function() {
      const peers = {
        a: {
          pending: false,
          status: {}
        },
        b: {
          pending: true,
          status: {
            c: 'd'
          }
        }
      };

      return get_room(peers).then(function(room) {
        const a = room.peers['a'];
        const b = room.peers['b'];

        a.pending.should.be.false;
        a.status.should.deep.equal({});
        a.first.should.be.false;

        b.pending.should.be.true;
        b.status.should.deep.equal({c: 'd'});
        return a.first.should.be.false;
      });
    });


    it('should emit events for initial peers', function(done) {
      const room = calling.room('test');

      room.on('peer_joined', function(peer) {
        peer.id.should.equal('a');
        peer.status.should.deep.equal({b: 'c'});
        peer.pending.should.be.true;
        return done();
      });

      room.connect();

      return channel.answer({
        room: 'test',
        peers: {
          a: {
            pending: true,
            status: {
              b: 'c'
            }
          }
        },
        status: {}
      });
    });

    it('should emit `peer_joined` on new peer', () => get_room().then(room => new Promise(function(resolve, reject) {
      room.on('peer_joined', function(user) {
        user.id.should.equal('a');
        user.status.should.deep.equal({a: 'b'});
        user.pending.should.be.true;
        return resolve();
      });

      return channel.receive({
        type: 'room_peer_add',
        room: 'test',
        user: 'a',
        pending: true,
        status: {a: 'b'}
      });
    })));


    it('should contain peer after joining', () => get_room().then(function(room) {
      room.peers.should.be.empty;

      channel.receive({
        type: 'room_peer_add',
        room: 'test',
        user: 'a',
        pending: true,
        status: {a: 'b'}
      });

      const user = room.peers['a'];
      user.id.should.equal('a');
      user.status.should.deep.equal({a: 'b'});
      return user.pending.should.be.true;
    }));


    it('should resolve `accepted()` on peer when accepting', () => get_room().then(function(room) {
      channel.receive({
        type: 'room_peer_add',
        room: 'test',
        user: 'a',
        pending: true,
        status: {a: 'b'}
      });

      const user = room.peers['a'];

      user.pending.should.be.true;

      channel.receive({
        type: 'room_peer_update',
        room: 'test',
        user: 'a',
        pending: false
      });

      return user.accepted().then(() => user.pending.should.be.false);
    }));


    it('should resolve `accepted()` on peer if never pending', () => get_room().then(function(room) {
      channel.receive({
        type: 'room_peer_add',
        room: 'test',
        user: 'a',
        pending: false,
        status: {a: 'b'}
      });

      return room.peers['a'].accepted();
    }));


    it('should reject `accepted()` on peer if peer leaves', function() {
      const peers = {
        a: {
          pending: true,
          status: {}
        }
      };

      return get_room(peers).then(function(room) {
        const promise = room.peers['a'].accepted();

        channel.receive({
          type: 'room_peer_rm',
          room: 'test',
          user: 'a'
        });

        return promise.should.be.rejected;
      });
    });


    it('should reject `accepted()` when room is left', function() {
      const peers = {
        a: {
          pending: true,
          status: {}
        }
      };

      return get_room(peers).then(function(room) {
        const promise = room.peers['a'].accepted();

        room.leave();
        channel.answer();

        return promise.should.be.rejected;
      });
    });


    it('should apply status from connect response', () => get_room({}, {a: 'b'}).then(room => room.status.should.deep.equal({a: 'b'})));


    it('should set status from `room_status` message', () => get_room().then(function(room) {
      room.status.should.be.empty;

      channel.receive({
        type: 'room_update',
        room: 'test',
        status: {a: 'b'}
      });

      return room.status.should.deep.equal({a: 'b'});
    }));


    it('should send `leave` message', () => get_room().then(function(room) {
      room.leave();

      return msg_compare(channel.sent[0], {
        type: 'room_leave',
        room: 'test'
      });
    }));


    it('should emit `left` when leaving', () => get_room().then(room => new Promise(function(resolve) {
      room.on('left', resolve);

      room.leave();
      return channel.answer();
    })));


    it('should emit `left` on peers when leaving', function() {
      const peers = {
        a: {
          status: {},
          pending: false
        }
      };

      return get_room(peers).then(room => new Promise(function(resolve) {
        room.peers['a'].on('left', resolve);

        room.leave();
        return channel.answer();
      }));
    });


    it('should emit `left` when channel closes');


    it('should clean up listeners after leaving', function() {
      channel.listeners('message').should.have.length(1);

      return get_room().then(function(room) {
        channel.listeners('message').should.have.length(2);

        room.leave();
        channel.answer();

        return channel.listeners('message').should.have.length(1);
      });
    });


    it('should let users change status before connecting');


    it('should let users change status after connecting');


    it('should emit `status_changed` on peer', function() {
      const peers = {
        a: {
          status: {},
          pending: false
        }
      };

      return get_room(peers).then(room => new Promise(function(resolve) {
        const peer = room.peers['a'];

        peer.on('status_changed', function(status) {
          status.should.deep.equal({a: 'b'});
          peer.status.should.deep.equal({a: 'b'});
          return resolve();
        });

        return channel.receive({
          type: 'room_peer_update',
          room: 'test',
          user: 'a',
          status: {a: 'b'}
        });
      }));
    });


    it('should emit events on peer', function() {
      const peers = {
        a: {
          status: {},
          pending: false
        }
      };

      return get_room(peers).then(room => new Promise(function(resolve) {
        const peer = room.peers['a'];

        peer.on('ev', function(data) {
          data.should.deep.equal({a: 'b'});
          return resolve();
        });

        return channel.receive({
          type: 'room_peer_from',
          room: 'test',
          user: 'a',
          event: 'ev',
          data: {a: 'b'}
        });
      }));
    });


    return it('should send `to` messages', function() {
      const peers = {
        a: {
          status: {},
          pending: false
        }
      };

      return get_room(peers).then(function(room) {
        const peer = room.peers['a'];

        peer.send('ev', {a: 'b'});

        return msg_compare(channel.sent[0], {
          type: 'room_peer_to',
          room: 'test',
          user: 'a',
          event: 'ev',
          data: {a: 'b'}
        });
      });
    });
  });


  describe('Incoming Invitation', () => it('should have tests'));


  return describe('Outgoing Invitation', () => it('should have tests'));
});
