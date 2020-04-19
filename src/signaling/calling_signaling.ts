/*
 * decaffeinate suggestions:
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

import { Channel, Signaling, SignalingPeer } from '../types';

export type CallingStatus = Record<string,any>;
type DataCb = (error: Error | undefined, data?: any) => void;

export type CallingState = "idle" | "connecting" | "connected" | "closed" | "failed";

export class Calling extends EventEmitter {
  id?: string;
  channel: Channel;
  room_options: Record<string,any>;
  next_tid: number;
  answers: Record<string,Deferred<any>|DataCb>;
  hello_p: Promise<string>;
  ping_timeout?: ReturnType<typeof setTimeout>;
  state: CallingState = "idle";

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
          hello_d.resolve(msg.server);
          return;

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
              answer.reject(new Error(msg.error));
            } else {
              answer.resolve(msg.data);
            }
          } else {
            if (msg.error != null) {
              answer(new Error(msg.error));
            } else {
              answer(undefined, msg.data);
            }
          }

          return;

        case 'invite_incoming':
          if ((msg.handle == null) || (msg.sender == null) || !msg.room || (msg.status == null) || (msg.peers == null) || (msg.data == null)) {
            console.log("Invalid message");
            return;
          }

          var invitation = new CallingInInvitation(this, msg.handle, msg.sender, msg.data);
          var room = new CallingInvitationRoom(invitation, this.room_options, msg.sender, msg.data);
          // TODO
          //room.signaling.init(msg);

          this.emit('invitation', room);
          return;
      }
    });

    this.channel.on('closed', () => {
      this.setState("closed");

      this.emit('closed');

      if (this.ping_timeout) {
        clearTimeout(this.ping_timeout);
        delete this.ping_timeout;
      }
    });
  }


  connect(): Promise<void> {
    if(this.state === "idle") {
      this.setState("connecting");
    }

    return this.channel.connect().then(() => {
      this.resetPing();

      return Promise.all([
        this.request({type: 'remote_ping', time: 30 * 1000}),
        this.hello_p
      ]).then(([ping, hello]) => {
        return hello;
      });
    }).then(() => {
      this.setState("connected");
    }).catch((err) => {
      this.setState("failed");
      throw err;
    });
  }

  request(msg: any, cb: DataCb): void;
  request(msg: any): Promise<any>;

  request(msg: any, cb?: DataCb): Promise<any> | undefined {
    msg.tid = this.next_tid++;

    this.channel.send(msg);
    this.resetPing();

    if (cb != null) {
      this.answers[msg.tid] = cb;
      return;
    } else {
      const defer = new Deferred<void>();
      this.answers[msg.tid] = defer;
      return defer.promise;
    }
  }


  ping(): Promise<void> {
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
      this.resetPing();
    }
    , 60 * 1000);
  }


  subscribe(nsid: string): Promise<CallingNamespace> {
    // uses callback to avoid race conditions with promises
    return new Promise((resolve, reject) => {
      this.request({
        type: 'ns_subscribe',
        namespace: nsid
      }, (err, data) => {
        if (err != null) {
          reject(err);
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

          resolve(namespace);
        }
      });
    });
  }


  register(namespace: string): Promise<void> {
    return this.request({
      type: 'ns_user_register',
      namespace
    });
  }


  unregister(namespace: string): Promise<void> {
    return this.request({
      type: 'ns_user_unregister',
      namespace
    });
  }


  room(room?: string, options?: Record<string,any>): CallingRoom {
    const signaling = this.room_signaling(room);
    return new CallingRoom(signaling, options || this.room_options || {});
  }


  room_signaling(room?: string): CallingSignaling {
    return new CallingSignaling(this, (status: Record<string,any>, cb: (test: any) => void) => {
      return this.request({
        type: 'room_join',
        room,
        status
      }, cb);
    });
  }


  setStatus(status: Record<string,any>): Promise<void> {
    return this.request({
      type: 'status',
      status
    });
  }


  close() {
    return this.channel.close();
  }

  private setState(state: CallingState) {
    this.state = state;
    this.emit("state_changed", state);
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

          this.addUser(msg.user, msg.status);
          return;
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
          user.emit('status_changed', user.status);
          return;
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
          user.emit('left');
          return;
        }

        case 'ns_room_add': {
          if ((msg.room == null) || (msg.status == null) || (msg.peers == null)) {
            console.log('Invalid message');
            return;
          }

          this.addRoom(msg.room, msg.status, msg.peers);
          return;
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
          room.emit('status_changed', room.status);
          return;
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
          room.emit('closed');
          return;
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
          this.emit('room_peer_joined', room, peer);
          return;
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
            peer.accepted_d.resolve();

            this.emit('room_changed', room);
            this.emit('peer_accepted', peer);
            peer.emit('accepted');
          }
          return;
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
          peer.emit('left');
          return;
        }
      }
    };

    this.calling.channel.on('message', message_handler);

    this.on('unsubscribed', () => {
      this.calling.channel.removeListener('message', message_handler);
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
    // TODO why not simple promise flow?
    return new Promise((resolve, reject) => {
      this.calling.request({
        type: 'ns_unsubscribe',
        namespace: this.id
      }, err => {
        if (err != null) {
          reject(err);
        } else {
          for (let _ in this.users) {
            const user = this.users[_];
            user.emit('left');
          }

          this.users = {};

          this.emit('unsubscribed');

          resolve();
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
  accepted_d: Deferred<void>;

  constructor(id: string, status: Record<string,any>, pending: boolean) {
    super();

    this.id = id;
    this.status = status;
    this.pending = pending;
    this.accepted_d = new Deferred<void>();

    if (!this.pending) {
      this.accepted_d.resolve();
    }

    this.on('left', () => {
      this.accepted_d.reject("Peer left");
    });
  }


  accepted() {
    return this.accepted_d.promise;
  }
}


export class CallingSignaling extends EventEmitter implements Signaling<CallingSignalingPeer> {

  id?: string;
  calling: Calling;
  connect_fun: (peer_status: Record<string,any>, cb: DataCb) => void;
  status: CallingStatus;
  peer_status: CallingStatus;
  peers: Record<string,CallingSignalingPeer>
  initialized: boolean;
  connect_p?: Promise<void>;

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
          this.emit('status_changed', this.status);
	  return;

        case 'room_peer_add':
          if ((msg.user == null) || (msg.pending == null) || (msg.status == null)) {
            console.log("Invalid message");
            return;
          }

          this.addPeer(msg.user, msg.status, msg.pending, true);
	  return;

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
          peer.emit('left');
	  return;

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
            peer.accepted_d.resolve();

            this.emit('peer_accepted');
            peer.emit('accepted');
	    return;
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
          peer.emit(msg.event, msg.data);
	  return;
      }
    };

    this.calling.channel.on('message', message_handler);

    this.on('left', () => {
      this.calling.channel.removeListener('message', message_handler);
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


  connect(): Promise<void> {
    if ((this.connect_p == null)) {
      this.connect_p = this.calling.connect().then(() => {
        return new Promise((resolve, reject) => {
          this.connect_fun(this.peer_status, (err, res) => {
            if (err != null) {
              reject(err);
            } else {
              if (res != null) {
                this.init(res);
              }

              if (!this.initialized) {
                reject(new Error("Missing information from connect response"));
                return;
              }

              resolve();
            }
          });
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


  async close(): Promise<void> {
    if(this.connect_p) {
      await this.connect_p;
      new Promise((resolve, reject) => {
        this.calling.request({
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

          resolve();
        });
      });
    } else {
      return Promise.resolve();
    }
  }


  setStatus(status: Record<string,any>): Promise<void> {
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


  invite(user: CallingNamespaceUser | string, data: any = {}): Promise<CallingOutInvitation> {
    const user_id = typeof user === "string" ? user : user.id;

    return new Promise((resolve, reject) => {
      this.calling.request({
        type: 'invite_send',
        room: this.id,
        user: user_id,
        data
      }, (err, res) => {
        if (err != null) {
          reject(err);
        } else {
          if ((res.handle == null)) {
            reject(new Error("Invalid response"));
            return;
          }

          const invitation = new CallingOutInvitation(this.calling, res.handle, user_id);
          resolve(invitation);
        }
      });
    });
  }


  setRoomStatusSafe(key: string, value: any, previous: any): Promise<void> {
    return new Promise((resolve, reject) => {
      this.calling.request({
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

        resolve();
      });
    });
  }


  setRoomStatus(key: string, value: any): Promise<void> {
    return new Promise((resolve, reject) => {
      this.calling.request({
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

        resolve();
      });
    });
  }


  register(namespace: string): Promise<void> {
    return this.calling.request({
      type: 'ns_room_register',
      namespace,
      room: this.id
    });
  }


  unregister(namespace: string): Promise<void> {
    return this.calling.request({
      type: 'ns_room_unregister',
      namespace,
      room: this.id
    });
  }
}


export class CallingSignalingPeer extends EventEmitter implements SignalingPeer {

  room: CallingSignaling;
  id: string;
  status: CallingStatus;
  pending: boolean;
  first: boolean;
  accepted_d: Deferred<void>;

  constructor(room: CallingSignaling, id: string, status: Record<string,any>, pending: boolean, first: boolean) {
    super();

    this.room = room;
    this.id = id;
    this.status = status;
    this.pending = pending;
    this.first = first;
    this.accepted_d = new Deferred<void>();

    if (!this.pending) {
      this.accepted_d.resolve();
    }

  }


  accepted(): Promise<void> {
    return this.accepted_d.promise;
  }


  send(event: string, data: any): Promise<void> {
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
          this.emit('handled', false);
      }
    };

    this.calling.channel.on('message', message_handler);

    this.on('handled', () => {
      this.calling.channel.removeListener('message', message_handler);
    });

  }


  signaling(): CallingSignaling {
    return new CallingSignaling(this.calling, (status, cb) => {
      this.emit('handled', true);
      this.calling.request({
        type: 'invite_accept',
        handle: this.handle,
        status
      }, cb);
    });
  }


  deny(): Promise<void> {
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
  user: string;
  defer: Deferred<boolean>;
  pending: boolean;

  constructor(calling: Calling, handle: string, user: string) {
    this.calling = calling;
    this.handle = handle;
    this.user = user;
    this.defer = new Deferred<boolean>();
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
      this.calling.channel.removeListener('message', message_handler);
    };

    this.defer.promise.then(cleanup, cleanup);

  }


  response(): Promise<boolean> {
    return this.defer.promise;
  }


  cancel(): Promise<void> {
    this.pending = false;

    return this.calling.request({
      type: 'invite_cancel',
      handle: this.handle
    }).then(() => {
      this.defer.reject(new Error("Invitation cancelled"));
    });
  }
}


export class CallingRoom extends Room<CallingSignalingPeer,CallingSignaling> {

  // TODO
  peers!: Record<string,CallingPeer>;

  constructor(signaling: CallingSignaling, options: Record<string,any>) {
    super(signaling, options);
    options = Object.assign({auto_connect: false}, options);
  }


  createPeer(pc: PeerConnection, signaling: CallingSignalingPeer): CallingPeer {
    return new CallingPeer(pc, signaling, this.local, this.options);
  }


  invite(user: CallingNamespaceUser | string, data: any): Promise<CallingOutInvitation> {
    return this.signaling.invite(user, data);
  }


  register(nsid: string): Promise<void> {
    return this.signaling.register(nsid);
  }


  unregister(nsid: string): Promise<void> {
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

    this.invitation.on('cancelled', () => {
      this.emit('cancelled');
    });

    this.invitation.on('handled', accepted => {
      this.emit('handled', accepted);
    });
  }


  sender(): CallingPeer {
    return this.peers[this.sender_id];
  }


  deny(): Promise<void> {
    return this.invitation.deny();
  }
}


export class CallingPeer extends RemotePeer {

  signaling!: CallingSignalingPeer;

  constructor(pc: PeerConnection, signaling: CallingSignalingPeer, local: LocalPeer, options: Record<string,any>) {
    super(pc, signaling, local, options);
  }


  async connect(): Promise<void> {
    await this.signaling.accepted()
    return super.connect();
  }
}

