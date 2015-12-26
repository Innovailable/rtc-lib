{Calling, CallingNamespace, CallingUser, CallingRoom, CallingPeer, CallingInInvitation, CallingOutInvitation} = require('../../../src/signaling/calling_signaling')
{EventEmitter} = require('events')
{Promise, Deferred} = require('../../../src/internal/promise')

msg_compare = (msg, cmp) ->
  cmp.tid = msg.tid
  msg.should.deep.equal(cmp)

class TestChannel extends EventEmitter

  constructor: () ->
    @sent = []
    @connect_d = new Deferred()

  connect: () ->
    return @connect_d.promise

  answer: (data, num=0) ->
    @receive({
      type: 'answer'
      tid: @sent[num].tid
      data: data
    })

  answerError: (error, num=0) ->
    @receive({
      type: 'answer'
      tid: @sent[num].tid
      error: error
    })

  receive: (msg) ->
    @emit('message', msg)

  send: (msg) ->
    @sent.push(msg)


describe 'CallingSignaling', () ->
  channel = null
  calling = null

  beforeEach () ->
    channel = new TestChannel()
    calling = new Calling(channel)

  describe 'Calling', () ->

    describe 'request', () ->

      it 'should use unique numeric transactions ids', () ->
        calling.request({type: 'test'})
        calling.request({type: 'test'})

        channel.sent[0].tid.should.be.a('number')
        channel.sent[1].tid.should.be.a('number')
        channel.sent[0].tid.should.not.equal(channel.sent[1].tid)


      it 'should call answer callback with data', (done) ->
        calling.request {type: 'test'}, (err, data) ->
          data.should.equal(42)
          done()

        channel.answer(42)


      it 'should call answer callback with error', (done) ->
        calling.request {type: 'test'}, (err, data) ->
          err.message.should.equal('Error')
          done()

        channel.answerError('Error')


      it 'should resolve promise with data', () ->
        promise = calling.request({type: 'test'})

        channel.answer(42)

        return promise.should.become(42)


      it 'should reject promise with error', () ->
        promise = calling.request({type: 'test'})

        channel.answerError('Error')

        return promise.should.be.rejectedWith('Error')


      it 'should handle answers with different order', () ->
        a = calling.request({type: 'test'})
        b = calling.request({type: 'test'})
        c = calling.request({type: 'test'})

        channel.answer('b', 1)
        channel.answer('c', 2)
        channel.answer('a', 0)

        return Promise.all([
          a.should.become('a')
          b.should.become('b')
          c.should.become('c')
        ])


      it 'should clean up answer handlers after resolving them', () ->
        p = calling.request({type: 'test'})
        channel.answer(42)

        return p.then (res) ->
          calling.answers.should.be.empty


    describe 'connect', () ->

      it 'should reject when channel connect rejects', () ->
        channel.connect_d.reject(new Error('Error'))
        calling.connect().should.be.rejected


      it 'should resolve connect promise on hello', () ->
        p = calling.connect()
        channel.connect_d.resolve()
        channel.receive({type: 'hello'})
        return p


      it 'should get id from hello', () ->
        p = calling.connect()
        channel.connect_d.resolve()

        channel.receive({
          type: 'hello'
          id: 42
        })

        return p.then () ->
          calling.id.should.equal(42)

      it 'should emit `closed` when channel closes'

    describe 'register', () ->

      it 'should send register command', () ->
        promise = calling.register('test')

        msg_compare(channel.sent[0], {
          type: 'register'
          namespace: 'test'
        })

        channel.answer()
        return promise


      it 'should send unregister command', () ->
        promise = calling.unregister('test')

        msg_compare(channel.sent[0], {
          type: 'unregister'
          namespace: 'test'
        })

        channel.answer()
        return promise


    describe 'subscribe', () ->

      it 'should send subscribe command', () ->
        calling.subscribe('test')

        msg_compare(channel.sent[0], {
          type: 'subscribe'
          namespace: 'test'
        })


      it 'should create namespace from answer', () ->
        promise = calling.subscribe('test')

        channel.answer({a: {}})

        promise.then (namespace) ->
          namespace.id.should.equal('test')
          namespace.users.should.have.key('a')


    describe 'join', () ->

      it 'should send join command on connect on room', () ->
        room = calling.join('test')
        promise = room.connect()

        msg_compare(channel.sent[0], {
          type: 'join'
          room: 'test'
          status: {}
        })

        channel.answer({
          room: 'test'
          peers: {}
          status: {a: 'b'}
        })

        return promise.then () ->
          room.id.should.equal('test')
          room.status.should.deep.equal({a: 'b'})


    describe 'status', () ->

      it 'should send status command', () ->
        calling.setStatus({a: 'b'})

        msg_compare(channel.sent[0], {
          type: 'status'
          status: {a: 'b'}
        })


    describe 'invitation', () ->

      it 'should throw event on incoming invitation', (done) ->
        calling.on 'invitation', (inv) ->
          inv.handle.should.equal(42)
          inv.user.should.equal('1234')
          inv.status.should.deep.equal({a: 'b'})
          inv.data.should.deep.equal({c: 'd'})
          done()

        channel.receive({
          type: 'invited'
          handle: 42
          user: "1234"
          status: {a: 'b'}
          data: {c: 'd'}
        })


  describe 'Namespace', () ->
    get_namespace = (users={}) ->
      promise = calling.subscribe('test')
      channel.answer(users)
      # reset sent messages
      channel.sent.length = 0
      return promise

    it 'should contain initial users', () ->
      return get_namespace({a: {}, b: {c: 'd'}}).then (namespace) ->
        namespace.users.should.have.keys('a', 'b')
        namespace.users['b'].status.should.deep.equal({c: 'd'})


    it 'should send unsubscribe message', () ->
      return get_namespace().then (namespace) ->
        p = namespace.unsubscribe()

        msg_compare(channel.sent[0], {
          type: 'unsubscribe'
          namespace: 'test'
        })

        channel.answer()

        return p


    it 'should emit `unsubscribed` event when unsubscribed', (done) ->
      return get_namespace().then (namespace) ->
        namespace.on 'unsubscribed', () ->
          done()

        p = namespace.unsubscribe()

        channel.answer()


    it 'should emit `unsubscribed` when channel is closed'


    it 'should emit `user_registered` when user registers', (done) ->
      return get_namespace().then (namespace) ->
        namespace.on 'user_registered', (user) ->
          user.id.should.equal('1234')
          user.status.should.deep.equal({a: 'b'})
          done()

        channel.receive({
          type: 'user_registered'
          namespace: 'test'
          user: '1234'
          status: {a: 'b'}
        })


    it 'should emit `user_left` when user leaves', (done) ->
      return get_namespace({a: {}}).then (namespace) ->
        namespace.on 'user_left', (user) ->
          user.id.should.equal('a')
          done()

        channel.receive({
          type: 'user_left'
          namespace: 'test'
          user: 'a'
        })


    it 'should emit `left` on user when user leaves', (done) ->
      return get_namespace({a: {}}).then (namespace) ->
        namespace.users['a'].on 'left', () ->
          done()

        channel.receive({
          type: 'user_left'
          namespace: 'test'
          user: 'a'
        })


    it 'should emit `left` on user when unsubscribing', (done) ->
      return get_namespace({a: {}}).then (namespace) ->
        namespace.users['a'].on 'left', () ->
          done()

        namespace.unsubscribe()
        channel.answer()


    it 'should emit `left` on user when channel closes'


    it 'should emit `status_changed` on status changes', (done) ->
      return get_namespace({a: {}}).then (namespace) ->
        user = namespace.users['a']

        user.on 'status_changed', (status) ->
          status.should.deep.equal({a: 'b'})
          user.status.should.deep.equal({a: 'b'})
          done()

        channel.receive({
          type: 'user_status'
          namespace: 'test'
          user: 'a'
          status: {a: 'b'}
        })


    it 'should remove listeners on channel after unsubscribing', () ->
      channel.listeners('message').length.should.equal(1)

      return get_namespace().then (namespace) ->
        channel.listeners('message').length.should.equal(2)

        p = namespace.unsubscribe()
        channel.answer()

        return p
      .then () ->
        channel.listeners('message').length.should.equal(1)
        return


  describe 'Room', () ->

    get_room = (peers={}, status={}) ->
      room = calling.join('test')
      promise = room.connect()

      channel.answer({
        room: 'test'
        peers: peers
        status: status
      })

      # reset sent messages
      channel.sent.length = 0

      return promise.then () ->
        return room


    it 'should contain initial peers', () ->
      peers = {
        a: {
          pending: false
          status: {}
        }
        b: {
          pending: true
          status: {
            c: 'd'
          }
        }
      }

      return get_room(peers).then (room) ->
        a = room.peers['a']
        b = room.peers['b']

        a.pending.should.be.false
        a.status.should.deep.equal({})
        a.first.should.be.false

        b.pending.should.be.true
        b.status.should.deep.equal({c: 'd'})
        a.first.should.be.false


    it 'should emit events for initial peers', (done) ->
      room = calling.join('test')

      room.on 'peer_joined', (peer) ->
        peer.id.should.equal('a')
        peer.status.should.deep.equal({b: 'c'})
        peer.pending.should.be.true
        done()

      room.connect()

      channel.answer({
        room: 'test'
        peers: {
          a: {
            pending: true
            status: {
              b: 'c'
            }
          }
        }
        status: {}
      })

    it 'should emit `peer_joined` on new peer', ()->
      return get_room().then (room) ->
        return new Promise (resolve, reject) ->
          room.on 'peer_joined', (user) ->
            user.id.should.equal('a')
            user.status.should.deep.equal({a: 'b'})
            user.pending.should.be.true
            resolve()

          channel.receive({
            type: 'peer_joined'
            room: 'test'
            user: 'a'
            pending: true
            status: {a: 'b'}
          })


    it 'should contain peer after joining', ()->
      return get_room().then (room) ->
        room.peers.should.be.empty

        channel.receive({
          type: 'peer_joined'
          room: 'test'
          user: 'a'
          pending: true
          status: {a: 'b'}
        })

        user = room.peers['a']
        user.id.should.equal('a')
        user.status.should.deep.equal({a: 'b'})
        user.pending.should.be.true


    it 'should resolve `accepted()` on peer when accepting', () ->
      return get_room().then (room) ->
        channel.receive({
          type: 'peer_joined'
          room: 'test'
          user: 'a'
          pending: true
          status: {a: 'b'}
        })

        user = room.peers['a']

        user.pending.should.be.true

        channel.receive({
          type: 'peer_accepted'
          room: 'test'
          user: 'a'
        })

        return user.accepted().then () ->
          user.pending.should.be.false


    it 'should resolve `accepted()` on peer if never pending', () ->
      return get_room().then (room) ->
        channel.receive({
          type: 'peer_joined'
          room: 'test'
          user: 'a'
          pending: false
          status: {a: 'b'}
        })

        return room.peers['a'].accepted()


    it 'should reject `accepted()` on peer if peer leaves', () ->
      peers = {
        a: {
          pending: true
          status: {}
        }
      }

      return get_room(peers).then (room) ->
        promise = room.peers['a'].accepted()

        channel.receive({
          type: 'peer_left'
          room: 'test'
          user: 'a'
        })

        return promise.should.be.rejected


    it 'should reject `accepted()` when room is left', () ->
      peers = {
        a: {
          pending: true
          status: {}
        }
      }

      return get_room(peers).then (room) ->
        promise = room.peers['a'].accepted()

        room.leave()
        channel.answer()

        return promise.should.be.rejected


    it 'should apply status from connect response', () ->
      return get_room({}, {a: 'b'}).then (room) ->
        room.status.should.deep.equal({a: 'b'})


    it 'should set status from `room_status` message', () ->
      return get_room().then (room) ->
        room.status.should.be.empty

        channel.receive({
          type: 'room_status'
          room: 'test'
          status: {a: 'b'}
        })

        room.status.should.deep.equal({a: 'b'})


    it 'should send `leave` message', () ->
      return get_room().then (room) ->
        room.leave()

        msg_compare(channel.sent[0], {
          type: 'leave'
          room: 'test'
        })


    it 'should emit `left` when leaving', () ->
      return get_room().then (room) ->
        new Promise (resolve) ->
          room.on('left', resolve)

          room.leave()
          channel.answer()


    it 'should emit `left` on peers when leaving', () ->
      peers = {
        a: {
          status: {}
          pending: false
        }
      }

      return get_room(peers).then (room) ->
        new Promise (resolve) ->
          room.peers['a'].on('left', resolve)

          room.leave()
          channel.answer()


    it 'should emit `left` when channel closes'


    it 'should clean up listeners after leaving', () ->
      channel.listeners('message').should.have.length(1)

      return get_room().then (room) ->
        channel.listeners('message').should.have.length(2)

        room.leave()
        channel.answer()

        channel.listeners('message').should.have.length(1)


    it 'should let users change status before connecting'


    it 'should let users change status after connecting'


    it 'should emit `status_changed` on peer', () ->
      peers = {
        a: {
          status: {}
          pending: false
        }
      }

      return get_room(peers).then (room) ->
        new Promise (resolve) ->
          peer = room.peers['a']

          peer.on 'status_changed', (status) ->
            status.should.deep.equal({a: 'b'})
            peer.status.should.deep.equal({a: 'b'})
            resolve()

          channel.receive({
            type: 'peer_status'
            room: 'test'
            user: 'a'
            status: {a: 'b'}
          })


    it 'should emit events on peer', () ->
      peers = {
        a: {
          status: {}
          pending: false
        }
      }

      return get_room(peers).then (room) ->
        new Promise (resolve) ->
          peer = room.peers['a']

          peer.on 'ev', (data) ->
            data.should.deep.equal({a: 'b'})
            resolve()

          channel.receive({
            type: 'from'
            room: 'test'
            user: 'a'
            event: 'ev'
            data: {a: 'b'}
          })


    it 'should send `to` messages', () ->
      peers = {
        a: {
          status: {}
          pending: false
        }
      }

      return get_room(peers).then (room) ->
        peer = room.peers['a']

        peer.send('ev', {a: 'b'})

        msg_compare(channel.sent[0], {
          type: 'to'
          room: 'test'
          user: 'a'
          event: 'ev'
          data: {a: 'b'}
        })


  describe 'Incoming Invitation', () ->
    it 'should have tests'


  describe 'Outgoing Invitation', () ->
    it 'should have tests'
