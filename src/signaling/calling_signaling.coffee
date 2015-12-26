{EventEmitter} = require('events')
{Promise, Deferred} = require('../internal/promise')


class Calling extends EventEmitter

  constructor: (@channel) ->
    @next_tid = 0
    @answers = {}

    hello_d = new Deferred()
    @hello_p = hello_d.promise

    @channel.on 'message', (msg) =>
      switch msg.type
        when 'hello'
          @id = msg.id
          hello_d.resolve(msg.server)

        when 'answer'
          if not msg.tid?
            console.log('Missing transaction id in answer')
            return

          answer = @answers[msg.tid]
          delete @answers[msg.tid]

          if not answer?
            console.log('Answer without expecting it')
            return

          if answer.resolve?
            if msg.error?
              answer.reject(new Error(msg.error))
            else
              answer.resolve(msg.data)
          else
            if msg.error?
              answer(new Error(msg.error))
            else
              answer(undefined, msg.data)

        when 'invited'
          if not msg.handle? or not msg.user? or not msg.status? or not msg.data?
            console.log("Invalid message")
            return

          invitation = new CallingInInvitation(@, msg.handle, msg.user, msg.status, msg.data)
          @emit('invitation', invitation)


  connect: () ->
    @channel.connect().then () =>
      return @hello_p


  request: (msg, cb) ->
    msg.tid = @next_tid++

    @channel.send(msg)

    if cb?
      @answers[msg.tid] = cb
      return
    else
      defer = new Deferred()
      @answers[msg.tid] = defer
      return defer.promise


  subscribe: (nsid) ->
    # uses callback to avoid race conditions with promises
    return new Promise (resolve, reject) =>
      @request {
        type: 'subscribe'
        namespace: nsid
      }, (err, data) =>
        if err?
          reject(err)
        else
          namespace = new CallingNamespace(@, nsid)

          namespace.on 'user_registered', (user) =>
            @emit('user_registered', user, namespace)

          for id, status of data
            namespace.addUser(id, status)

          resolve(namespace)


  register: (namespace) ->
    return @request({
      type: 'register'
      namespace: namespace
    })


  unregister: (namespace) ->
    return @request({
      type: 'unregister'
      namespace: namespace
    })


  join: (room) ->
    return new CallingRoom @, (status, cb) =>
      @request({
        type: 'join'
        room: room
        status: status
      }, cb)


  setStatus: (status) ->
    return @request({
      type: 'status'
      status: status
    })


class CallingNamespace extends EventEmitter

  constructor: (@calling, @id) ->
    @users = {}

    message_handler = (msg) =>
      if msg.namespace != @id
        return

      switch msg.type
        when 'user_registered'
          if not msg.user? or not msg.status?
            console.log('Invalid message')
            return

          @addUser(msg.user, msg.status)

        when 'user_status'
          if not msg.user? or not msg.status?
            console.log('Invalid message')
            return

          user = @users[msg.user]

          if not user?
            console.log('Unknown user in status change')
            return

          user.status = msg.status
          user.emit('status_changed', user.status)

        when 'user_left'
          if not msg.user?
            console.log('Invalid message')
            return

          user = @users[msg.user]

          if not user?
            console.log('Unknown user leaving')
            return

          user.emit('left')
          @emit('user_left', user)
          delete @users[msg.user]

    @calling.channel.on('message', message_handler)

    @on 'unsubscribed', () =>
      @calling.channel.removeListener('message', message_handler)


  addUser: (id, status) ->
    user = new CallingUser(id, status)
    @users[id] = user
    @emit('user_registered', user)
    return user


  unsubscribe: () ->
    return new Promise (resolve, reject) =>
      @calling.request {
        type: 'unsubscribe'
        namespace: @id
      }, (err) =>
        if err?
          reject(err)
        else
          for _, user of @users
            user.emit('left')

          @users = {}

          @emit('unsubscribed')

          resolve()


class CallingUser extends EventEmitter

  constructor: (@id, @status) ->


class CallingRoom extends EventEmitter

  constructor: (@calling, @connect_fun) ->
    @peer_status = {}
    @peers = {}

    message_handler = (msg) =>
      if msg.room != @id
        return

      switch msg.type
        when 'room_status'
          if not msg.status?
            console.log("Invalid message")
            return

          @status = msg.status
          @emit('status_changed', @status)

        when 'peer_joined'
          if not msg.user? or not msg.pending? or not msg.status?
            console.log("Invalid message")
            return

          @addPeer(msg.user, msg.status, msg.pending, true)

        when 'peer_accepted'
          if not msg.user?
            console.log("Invalid message")
            return

          peer = @peers[msg.user]

          if not peer?
            console.log("Unknown peer accepted")
            return

          peer.pending = false
          peer.accepted_d.resolve()

        when 'peer_left'
          if not msg.user?
            console.log("Invalid message")
            return

          peer = @peers[msg.user]

          if not peer?
            console.log("Unknown peer accepted")
            return

          peer.accepted_d.reject("User left")
          peer.emit('left')

          delete @peers[msg.user]

        when 'peer_status'
          if not msg.user? or not msg.status?
            console.log("Invalid message")
            return

          peer = @peers[msg.user]

          if not peer?
            console.log("Unknown peer accepted")
            return

          peer.status = msg.status
          peer.emit('status_changed', peer.status)

        when 'from'
          if not msg.user? or not msg.event? or not msg.data?
            console.log("Invalid message")
            return

          peer = @peers[msg.user]

          if not peer?
            console.log("Unknown peer accepted")
            return

          peer.emit(msg.event, msg.data)

    @calling.channel.on('message', message_handler)

    @on 'left', () =>
      @calling.channel.removeListener('message', message_handler)


  connect: () ->
    if not @connect_p?
      @connect_p = new Promise (resolve, reject) =>
        @connect_fun @peer_status, (err, res) =>
          if err?
            reject(err)
          else
            if not res.room? or not res.peers?
              reject(new Error("Invalid response from server"))
              return

            @id = res.room
            @status = res.status

            for user, data of res.peers
              @addPeer(user, data.status, data.pending, false)

            resolve()

    return @connect_p


  addPeer: (id, status, pending, first) ->
    peer = new CallingPeer(@, id, status, pending, first)
    @peers[id] = peer
    @emit('peer_joined', peer)
    return peer


  leave: () ->
    return new Promise (resolve, reject) =>
      @calling.request {
        type: 'leave'
        room: @id
      }, (err) =>
        @emit('left')

        for _, peer of @peers
          peer.emit('left')
          peer.accepted_d.reject("You left the room")

        resolve()


  setStatus: (status) ->
    @peer_status = status

    if @connect_p?
      return @calling.request({
        type: 'peer_status'
        room: @id
        status: status
      })
    else
      return Promise.resolve()


  invite: (user, data={}) ->
    return new Promise (resolve, reject) =>
      @calling.request {
        type: 'invite'
        room: @id
        user: user.id
        data: data
      }, (err, res) =>
        if err?
          reject(err)
        else
          if not res.handle?
            reject(new Error("Invalid response"))
            return

          invitation = new CallingOutInvitation(@calling, res.handle)
          resolve(invitation)


class CallingPeer extends EventEmitter

  constructor: (@room, @id, @status, @pending, @first) ->
    @accepted_d = new Deferred()

    if not @pending
      @accepted_d.resolve()

    return


  accepted: () ->
    return @accepted_d.promise


  send: (event, data) ->
    return @room.calling.request({
      type: 'to'
      room: @room.id
      user: @id
      event: event
      data: data
    })


class CallingInInvitation extends EventEmitter

  constructor: (@calling, @handle, @user, @status, @data) ->
    @cancelled = false

    message_handler = (msg) =>
      if msg.handle != @handle
        return

      switch msg.type
        when 'invite_cancelled'
          @cancelled = true
          @emit('cancelled')
          @emit('handled')

    @calling.channel.on('message', message_handler)

    @on 'handled', () =>
      @calling.channel.removeListener('message', message_handler)

    return

  
  accept: () ->
    @emit('handled')
    return new CallingRoom @calling, (status, cb) =>
      @calling.request({
        type: 'accept'
        handle: @handle
        status: status
      }, cb)


  deny: () ->
    @emit('handled')
    return @calling.request({
      type: 'deny'
      handle: @handle
    })


class CallingOutInvitation

  constructor: (@calling, @handle) ->
    @defer = new Deferred()

    message_handler = (msg) =>
      if msg.handle != @handle
        return

      switch msg.type
        when 'invite_response'
          if not msg.accepted?
            console.log("Invalid message")
            return

          @defer.resolve(msg.accepted)

    @calling.channel.on('message', message_handler)

    cleanup = () =>
      @calling.channel.removeListener('message', message_handler)

    @defer.promise.then(cleanup, cleanup)

    return


  response: () ->
    return @defer.promise


  cancel: () ->
    return @calling.request({
      type: 'invite_cancel'
      handle: @handle
    }).then () =>
      @defer.reject(new Error("Invitation cancelled"))
      return

module.exports = {
  Calling: Calling
  CallingNamespace: CallingNamespace
  CallingUser: CallingUser
  CallingRoom: CallingRoom
  CallingPeer: CallingPeer
  CallingInInvitation: CallingInInvitation
  CallingOutInvitation: CallingOutInvitation
}
