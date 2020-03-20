/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS201: Simplify complex destructure assignments
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { EventEmitter } from 'events';
import { Deferred } from '../internal/promise';

import { Room } from '../room';
import { RemotePeer } from '../remote_peer';
import { LocalPeer } from '../local_peer';
import { PeerConnection } from '../peer_connection';

import { Channel } from './signaling';

type CallingStatus = Record<string,any>;
type DataCb = (error: Error | undefined, data?: any) => void;

export class Calling extends EventEmitter {
  id?: string;
  channel: Channel;
  room_options: Record<string,any>;
  next_tid: number;
  answers: Record<string,Deferred<any>|DataCb>;
  hello_p: Promise<string>;
  ping_timeout?: NodeJS.Timeout;

  constructor(channel: Channel, room_options: Record<string,any>) {
      super();

    this.channel = channel;
    this.room_options = room_options;
    this.next_tid = 0;
    this.answers = {};

    const hello_d = new Deferred<string>();
    this.hello_p = hello_d.promise;

    this.channel.on('message', msg => {
      this.resetPing();

      switch (msg.type) {
        case 'hello':
          this.id = msg.id;
          return hello_d.resolve(msg.server);

        case 'answer':
          if ((msg.tid == null)) {
            console.log('Missing transaction id in answer');
            return;
          }

          var answer = this.answers[msg.tid];
          delete this.answers[msg.tid];

          if ((answer == null)) {
            console.log('Answer without expecting it');
            return;
          }

          if ('resolve' in answer) {
            if (msg.error != null) {
              return answer.reject(new Error(msg.error));
            } else {
              return answer.resolve(msg.data);
            }
          } else {
            if (msg.error != null) {
              return answer(new Error(msg.error));
            } else {
              return answer(undefined, msg.data);
            }
          }

        case 'invite_incoming':
          if ((msg.handle == null) || (msg.sender == null) || !msg.room || (msg.status == null) || (msg.peers == null) || (msg.data == null)) {
            console.log("Invalid message");
            return;
          }

          var invitation = new CallingInInvitation(this, msg.handle, msg.sender, msg.data);
          var room = new CallingInvitationRoom(invitation, this.room_options, msg.sender, msg.data);
          // TODO
          //room.signaling.init(msg);

          return this.emit('invitation', room);
      }
    });

    this.channel.on('closed', () => {
      this.emit('closed');

      if (this.ping_timeout) {
        clearTimeout(this.ping_timeout);
        return delete this.ping_timeout;
      }
    });
  }


  connect(): Promise<unknown> {
    return this.channel.connect().then(() => {
      this.resetPing();

      return Promise.all([
        this.request({type: 'remote_ping', time: 30 * 1000}),
        this.hello_p
      ]).then(function(...args) {
        const [ping, hello] = Array.from(args[0]);
        return hello;
      });
    });
  }

  request(msg: any, cb: DataCb): void;
  request(msg: any): Promise<any>;

  request(msg: any, cb?: DataCb): Promise<any> | void {
    msg.tid = this.next_tid++;

    this.channel.send(msg);
    this.resetPing();

    if (cb != null) {
      this.answers[msg.tid] = cb;
      return;
    } else {
      const defer = new Deferred();
      this.answers[msg.tid] = defer;
      return defer.promise;
    }
  }


  ping(): Promise<unknown> {
    return this.request({
      type: 'ping'
    });
  }


  resetPing(): void {
    if (this.ping_timeout) {
      clearTimeout(this.ping_timeout);
    }

    this.ping_timeout = setTimeout(() => {
      this.ping();
      return this.resetPing();
    }
    , 60 * 1000);
  }


  subscribe(nsid: string): Promise<CallingNamespace> {
    // uses callback to avoid race conditions with promises
    return new Promise((resolve, reject) => {
      return this.request({
        type: 'ns_subscribe',
        namespace: nsid
      }, (err, data) => {
        if (err != null) {
          return reject(err);
        } else {
          let id, status;
          const namespace = new CallingNamespace(this, nsid);

          // TODO
          for (const [id, status] of Object.entries(data.users)) {
            namespace.addUser(id, status as Record<string,any>);
          }

          // TODO
          for (const [id, room] of Object.entries(<Record<string,any>>data.rooms)) {
            namespace.addRoom(id, room.status, room.peers);
          }

          return resolve(namespace);
        }
      });
    });
  }


  register(namespace: string): Promise<unknown> {
    return this.request({
      type: 'ns_user_register',
      namespace
    });
  }


  unregister(namespace: string): Promise<unknown> {
    return this.request({
      type: 'ns_user_unregister',
      namespace
    });
  }


  room(room: string, options: Record<string,any>): CallingRoom {
    const signaling = this.room_signaling(room);
    return new CallingRoom(signaling, options || this.room_options);
  }


  room_signaling(room: string): CallingSignaling {
    return new CallingSignaling(this, (status: Record<string,any>, cb: (test: any) => void) => {
      return this.request({
        type: 'room_join',
        room,
        status
      }, cb);
    });
  }


  setStatus(status: Record<string,any>): Promise<unknown> {
    return this.request({
      type: 'status',
      status
    });
  }


  close() {
    return this.channel.close();
  }
}


export class CallingNamespace extends EventEmitter {

  calling: Calling;
  id: string;
  // TODO
  users: Record<string,CallingNamespaceUser>
  rooms: Record<string,CallingNamespaceRoom>

  constructor(calling: Calling, id: string) {
      super();

    this.calling = calling;
    this.id = id;
    this.users = {};
    this.rooms = {};

    const message_handler = (msg: any) => {
      if (msg.namespace !== this.id) {
        return;
      }

      switch (msg.type) {
        case 'ns_user_add': {
          if ((msg.user == null) || (msg.status == null)) {
            console.log('Invalid message');
            return;
          }

          return this.addUser(msg.user, msg.status);
        }

        case 'ns_user_update': {
          if ((msg.user == null) || (msg.status == null)) {
            console.log('Invalid message');
            return;
          }

          const user = this.users[msg.user];

          if ((user == null)) {
            console.log('Unknown user in status change');
            return;
          }

          user.status = msg.status;
          this.emit('user_changed', user);
          this.emit('user_status_changed', user, user.status);
          return user.emit('status_changed', user.status);
        }

        case 'ns_user_rm': {
          if ((msg.user == null)) {
            console.log('Invalid message');
            return;
          }

          const user = this.users[msg.user];

          if ((user == null)) {
            console.log('Unknown user leaving');
            return;
          }

          delete this.users[msg.user];

          this.emit('user_left', user);
          return user.emit('left');
        }

        case 'ns_room_add': {
          if ((msg.room == null) || (msg.status == null) || (msg.peers == null)) {
            console.log('Invalid message');
            return;
          }

          return this.addRoom(msg.room, msg.status, msg.peers);
        }

        case 'ns_room_update': {
          if ((msg.room == null) || (msg.status == null)) {
            console.log('Invalid message');
            return;
          }

          var room = this.rooms[msg.room];

          if ((room == null)) {
            console.log('Invalid room');
            return;
          }

          room.status = msg.status;

          this.emit('room_status_changed', room, room.status);
          return room.emit('status_changed', room.status);
        }

        case 'ns_room_rm': {
          if ((msg.room == null)) {
            console.log('Invalid message');
            return;
          }

          const room = this.rooms[msg.room];

          if ((room == null)) {
            console.log('Invalid room');
            return;
          }

          delete this.rooms[msg.room];

          this.emit('room_closed');
          return room.emit('closed');
        }

        case 'ns_room_peer_add': {
          if ((msg.room == null) || (msg.user == null) || (msg.status == null) || (msg.pending == null)) {
            console.log('Invalid message');
            return;
          }

          room = this.rooms[msg.room];

          if ((room == null)) {
            console.log('Invalid room');
            return;
          }

          var peer = room.addPeer(msg.user, msg.status, msg.pending);

          this.emit('room_changed', room);
          return this.emit('room_peer_joined', room, peer);
        }

        case 'ns_room_peer_update': {
          if ((msg.room == null) || (msg.user == null)) {
            console.log('Invalid message');
            return;
          }

          const room = this.rooms[msg.room];
          const peer = room != null ? room.peers[msg.user] : undefined;

          if ((peer == null)) {
            console.log('Invalid peer');
            return;
          }

          if (msg.status != null) {
            peer.status = msg.status;

            this.emit('room_changed', room);
            this.emit('room_peer_status_changed', room, peer, peer.status);
            peer.emit('status_changed', peer.status);
          }

          if ((msg.pending != null) && (msg.pending === false)) {
            peer.pending = false;
            peer.accepted_d.resolve(null);

            this.emit('room_changed', room);
            this.emit('peer_accepted', peer);
            return peer.emit('accepted');
          }
          break;
        }

        case 'ns_room_peer_rm': {
          if ((msg.room == null) || (msg.user == null)) {
            console.log('Invalid message');
            return;
          }

          const room = this.rooms[msg.room];
          const peer = room != null ? room.peers[msg.user] : undefined;

          if ((peer == null)) {
            console.log('Invalid peer');
            return;
          }

          delete this.rooms[msg.room].peers[msg.user];

          this.emit('room_changed', room);
          this.emit('room_peer_left', room, peer);
          return peer.emit('left');
        }
      }
    };

    this.calling.channel.on('message', message_handler);

    this.on('unsubscribed', () => {
      return this.calling.channel.removeListener('message', message_handler);
    });
  }


  addUser(id: string, status: Record<string,any>) {
    const user = new CallingNamespaceUser(id, status);
    this.users[id] = user;
    this.emit('user_registered', user);
    return user;
  }


  addRoom(id: string, status: Record<string,any>, peers: any) {
    const room = new CallingNamespaceRoom(id, status);

    for (let peer_id in peers) {
      const peer = peers[peer_id];
      room.addPeer(peer_id, peer.status, peer.pending);
    }

    this.rooms[id] = room;
    this.emit('room_changed', room);
    this.emit('room_registered', room);
    return room;
  }


  unsubscribe() {
    return new Promise((resolve, reject) => {
      return this.calling.request({
        type: 'ns_unsubscribe',
        namespace: this.id
      }, err => {
        if (err != null) {
          return reject(err);
        } else {
          for (let _ in this.users) {
            const user = this.users[_];
            user.emit('left');
          }

          this.users = {};

          this.emit('unsubscribed');

          return resolve();
        }
      });
    });
  }
}


export class CallingNamespaceUser extends EventEmitter {

  id: string;
  status: CallingStatus;
  pending: boolean;

  // TODO probably remove pending
  constructor(id: string, status: Record<string,any>, pending = false) {
      super();

    this.id = id;
    this.status = status;
    this.pending = pending;
  }
}


export class CallingNamespaceRoom extends EventEmitter {

  id: string;
  status: CallingStatus;
  peers: Record<string,CallingNamespaceRoomPeer>;

  constructor(id: string, status: Record<string,any>) {
      super();

    this.id = id;
    this.status = status;
    this.peers = {};
  }


  addPeer(id: string, status: Record<string,any>, pending: boolean): CallingNamespaceUser {
    const peer = new CallingNamespaceRoomPeer(id, status, pending);
    this.peers[id] = peer;
    this.emit('peer_joined', peer);
    return peer;
  }
}


export class CallingNamespaceRoomPeer extends EventEmitter {

  id: string;
  status: CallingStatus;
  pending: boolean;
  accepted_d: Deferred;

  constructor(id: string, status: Record<string,any>, pending: boolean) {
      super();

    this.id = id;
    this.status = status;
    this.pending = pending;
    this.accepted_d = new Deferred();

    if (!this.pending) {
      this.accepted_d.resolve(null);
    }

    this.on('left', () => {
      return this.accepted_d.reject("Peer left");
    });
  }


  accepted() {
    return this.accepted_d.promise;
  }
}


export class CallingSignaling extends EventEmitter {

  id?: string;
  calling: Calling;
  connect_fun: (peer_status: Record<string,any>, cb: DataCb) => void;
  status: CallingStatus;
  peer_status: CallingStatus;
  peers: Record<string,CallingSignalingPeer>
  initialized: boolean;
  connect_p?: Promise<unknown>;

  constructor(calling: Calling, connect_fun: (peer_status: Record<string,any>, cb: DataCb) => void) {
      super();

    this.calling = calling;
    this.connect_fun = connect_fun;
    this.peer_status = {};
    this.peers = {};
    this.status = {};

    this.initialized = false;

    const message_handler = (msg: any) => {
      if (msg.room !== this.id) {
        return;
      }

      switch (msg.type) {
        case 'room_update':
          if ((msg.status == null)) {
            console.log("Invalid message");
            return;
          }

          this.status = msg.status;
          return this.emit('status_changed', this.status);

        case 'room_peer_add':
          if ((msg.user == null) || (msg.pending == null) || (msg.status == null)) {
            console.log("Invalid message");
            return;
          }

          return this.addPeer(msg.user, msg.status, msg.pending, true);

        case 'room_peer_rm':
          console.log('removing');
          if ((msg.user == null)) {
            console.log("Invalid message");
            return;
          }

          var peer = this.peers[msg.user];

          if ((peer == null)) {
            console.log("Unknown peer accepted");
            return;
          }

          delete this.peers[msg.user];
          peer.accepted_d.reject("User left");
          console.log('removed', this.peers);

          this.emit('peer_left', peer);
          return peer.emit('left');

        case 'room_peer_update':
          if ((msg.user == null)) {
            console.log("Invalid message");
            return;
          }

          peer = this.peers[msg.user];

          if ((peer == null)) {
            console.log("Unknown peer accepted");
            return;
          }

          if (msg.status != null) {
            peer.status = msg.status;

            this.emit('peer_status_changed', peer, peer.status);
            peer.emit('status_changed', peer.status);
          }

          if ((msg.pending != null) && (msg.pending === false)) {
            peer.pending = false;
            peer.accepted_d.resolve(null);

            this.emit('peer_accepted');
            return peer.emit('accepted');
          }
          break;


        case 'room_peer_from':
          if ((msg.user == null) || (msg.event == null)) {
            console.log("Invalid message", msg);
            return;
          }

          peer = this.peers[msg.user];

          if ((peer == null)) {
            console.log("Unknown peer accepted");
            return;
          }

          this.emit('peer_left');
          return peer.emit(msg.event, msg.data);
      }
    };

    this.calling.channel.on('message', message_handler);

    this.on('left', () => {
      return this.calling.channel.removeListener('message', message_handler);
    });
  }


  init(data: any): void {
    if (this.initialized) {
      throw new Error("Room is already initialized");
    }

    if ((data.room == null) || (data.peers == null) || (data.status == null)) {
      console.log(data);
      throw new Error("Invalid initialization data");
    }

    this.id = data.room;
    this.status = data.status;

    for (let user in data.peers) {
      const entry = data.peers[user];
      this.addPeer(user, entry.status, entry.pending, false);
    }

    this.initialized = true;
  }


  connect(): Promise<unknown> {
    if ((this.connect_p == null)) {
      this.connect_p = new Promise((resolve, reject) => {
        return this.connect_fun(this.peer_status, (err, res) => {
          if (err != null) {
            return reject(err);
          } else {
            if (res != null) {
              this.init(res);
            }

            if (!this.initialized) {
              reject(new Error("Missing information from connect response"));
              return;
            }

            return resolve();
          }
        });
      });
    }

    return this.connect_p;
  }


  addPeer(id: string, status: Record<string,any>, pending: boolean, first: boolean): CallingSignalingPeer {
    const peer = new CallingSignalingPeer(this, id, status, pending, first);
    this.peers[id] = peer;
    this.emit('peer_joined', peer);
    return peer;
  }


  close(): Promise<unknown> {
    return new Promise((resolve, reject) => {
      return this.calling.request({
        type: 'room_leave',
        room: this.id
      }, err => {
        this.emit('left');

        for (let _ in this.peers) {
          const peer = this.peers[_];
          peer.emit('left');
          peer.accepted_d.reject("You left the room");
        }

        this.emit('closed');

        return resolve();
      });
    });
  }


  setStatus(status: Record<string,any>): Promise<unknown> {
    this.peer_status = status;

    if (this.connect_p != null) {
      return this.calling.request({
        type: 'room_peer_status',
        room: this.id,
        status
      });
    } else {
      return Promise.resolve();
    }
  }


  invite(user: CallingNamespaceUser, data: any): Promise<CallingOutInvitation> {
    if (data == null) { data = {}; }
    return new Promise((resolve, reject) => {
      return this.calling.request({
        type: 'invite_send',
        room: this.id,
        user: typeof user === 'string' ? user : user.id,
        data
      }, (err, res) => {
        if (err != null) {
          return reject(err);
        } else {
          if ((res.handle == null)) {
            reject(new Error("Invalid response"));
            return;
          }

          const invitation = new CallingOutInvitation(this.calling, res.handle, user);
          return resolve(invitation);
        }
      });
    });
  }


  setRoomStatusSafe(key: string, value: any, previous: any): Promise<unknown> {
    return new Promise((resolve, reject) => {
      return this.calling.request({
        type: 'room_status',
        room: this.id,
        key,
        value,
        check: true,
        previous
      }, err => {
        if (err) {
          reject(err);
          return;
        }

        this.status[key] = value;
        this.emit('status_changed', this.status);

        return resolve();
      });
    });
  }


  setRoomStatus(key: string, value: any): Promise<unknown> {
    return new Promise((resolve, reject) => {
      return this.calling.request({
        type: 'room_status',
        room: this.id,
        key,
        value
      }, err => {
        if (err) {
          reject(err);
          return;
        }

        this.status[key] = value;
        this.emit('status_changed', this.status);

        return resolve();
      });
    });
  }


  register(namespace: string): Promise<unknown> {
    return this.calling.request({
      type: 'ns_room_register',
      namespace,
      room: this.id
    });
  }


  unregister(namespace: string): Promise<unknown> {
    return this.calling.request({
      type: 'ns_room_unregister',
      namespace,
      room: this.id
    });
  }
}


export class CallingSignalingPeer extends EventEmitter {

  room: CallingSignaling;
  id: string;
  status: CallingStatus;
  pending: boolean;
  first: boolean;
  accepted_d: Deferred;

  constructor(room: CallingSignaling, id: string, status: Record<string,any>, pending: boolean, first: boolean) {
      super();

    this.room = room;
    this.id = id;
    this.status = status;
    this.pending = pending;
    this.first = first;
    this.accepted_d = new Deferred();

    if (!this.pending) {
      this.accepted_d.resolve(null);
    }

  }


  accepted(): Promise<unknown> {
    return this.accepted_d.promise;
  }


  send(event: string, data: any): Promise<unknown> {
    return this.room.calling.request({
      type: 'room_peer_to',
      room: this.room.id,
      user: this.id,
      event,
      data
    });
  }
}


export class CallingInInvitation extends EventEmitter {

  calling: Calling;
  handle: string;
  sender: string;
  // TODO
  data: any;
  cancelled: boolean;

  // TODO probably remove sender and data
  constructor(calling: Calling, handle: string, sender: string, data: any) {
      super();

    this.calling = calling;
    this.handle = handle;
    this.sender = sender;
    this.data = data;
    this.cancelled = false;

    const message_handler = (msg: any) => {
      if (msg.handle !== this.handle) {
        return;
      }

      switch (msg.type) {
        case 'invite_cancelled':
          this.cancelled = true;
          this.emit('cancelled');
          return this.emit('handled', false);
      }
    };

    this.calling.channel.on('message', message_handler);

    this.on('handled', () => {
      return this.calling.channel.removeListener('message', message_handler);
    });

  }


  signaling(): CallingSignaling {
    return new CallingSignaling(this.calling, (status, cb) => {
      this.emit('handled', true);
      return this.calling.request({
        type: 'invite_accept',
        handle: this.handle,
        status
      }, cb);
    });
  }


  deny(): Promise<unknown> {
    this.emit('handled', false);
    return this.calling.request({
      type: 'invite_deny',
      handle: this.handle
    });
  }
}


export class CallingOutInvitation {

  calling: Calling;
  handle: string;
  user: CallingNamespaceUser;
  defer: Deferred<boolean>;
  pending: boolean;

  constructor(calling: Calling, handle: string, user: CallingNamespaceUser) {
    this.calling = calling;
    this.handle = handle;
    this.user = user;
    this.defer = new Deferred();
    this.pending = true;

    const message_handler = (msg: any) => {
      if (msg.handle !== this.handle) {
        return;
      }

      switch (msg.type) {
        case 'invite_response':
          if ((msg.accepted == null)) {
            console.log("Invalid message");
            return;
          }

          this.pending = false;
          return this.defer.resolve(msg.accepted);
      }
    };

    this.calling.channel.on('message', message_handler);

    const cleanup = () => {
      return this.calling.channel.removeListener('message', message_handler);
    };

    this.defer.promise.then(cleanup, cleanup);

  }


  response(): Promise<unknown> {
    return this.defer.promise;
  }


  cancel(): Promise<unknown> {
    this.pending = false;

    return this.calling.request({
      type: 'invite_cancel',
      handle: this.handle
    }).then(() => {
      this.defer.reject(new Error("Invitation cancelled"));
    });
  }
}


export class CallingRoom extends Room {

  // TODO
  signaling!: CallingSignaling;
  peers!: Record<string,CallingPeer>;

  constructor(signaling: CallingSignaling, options: Record<string,any>) {
    super(signaling, options);
    options = Object.assign({auto_connect: false}, options);
  }


  createPeer(pc: PeerConnection, signaling: CallingSignalingPeer): CallingPeer {
    return new CallingPeer(pc, signaling, this.local, this.options);
  }


  invite(user: CallingNamespaceUser, data: any): Promise<unknown> {
    return this.signaling.invite(user, data);
  }


  register(nsid: string): Promise<unknown> {
    return this.signaling.register(nsid);
  }


  unregister(nsid: string): Promise<unknown> {
    return this.signaling.unregister(nsid);
  }
}


export class CallingInvitationRoom extends CallingRoom {

  invitation: CallingInInvitation;
  sender_id: string;
  // TODO
  data: any;

  constructor(invitation: CallingInInvitation, options: Record<string,any>, sender_id: string, data: any) {
      super(invitation.signaling(), options);

    this.invitation = invitation;
    this.sender_id = sender_id;
    this.data = data;
    super(this.invitation.signaling(), options);

    this.invitation.on('cancelled', () => {
      return this.emit('cancelled');
    });

    this.invitation.on('handled', accepted => {
      return this.emit('handled', accepted);
    });
  }


  sender(): CallingPeer {
    return this.peers[this.sender_id];
  }


  deny(): Promise<unknown> {
    return this.invitation.deny();
  }
}


class CallingPeer extends RemotePeer {

  signaling!: CallingSignalingPeer;

  constructor(pc: PeerConnection, signaling: CallingSignalingPeer, local: LocalPeer, options: Record<string,any>) {
    super(pc, signaling, local, options);
  }


  connect(): Promise<unknown> {
    return this.signaling.accepted().then(() => {
      return CallingPeer.prototype.connect.call(this);
    });
  }
}

