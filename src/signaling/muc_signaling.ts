/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { Deferred } from '../internal/promise';
import { Signaling, SignalingPeer, Channel } from './signaling';
import { EventEmitter } from 'events';


/**
 * @module rtc.signaling
 */

/**
 * Signaling peer for multi user chats.
 *
 * For a detailed description of the signaling protocol see `rtc.signaling.MucSignaling`
 *
 * @extends rtc.signaling.SignalingPeer
 * @class rtc.signaling.MucSignalingPeer
 *
 * @constructor
 * @param {rtc.signaling.Channel} channel The channel to the siganling server
 * @param {String} peer_id The id of the remote peer
 * @param {Object} status The status of the remote peer
 * @param {Boolean} first Whether the local peer was in the room before the remote peer
 */
export class MucSignalingPeer extends SignalingPeer {
  channel: Channel;
  id: string;
  status: Record<string,any>;
  first: boolean;

  /**
   * The id of the remote peer
   * @property id
   * @type String
   */

  constructor(channel: Channel, id: string, status: Record<string,any>, first: boolean) {
      super();

    this.channel = channel;
    this.id = id;
    this.status = status;
    this.first = first;
    var recv_msg = (data: any) => {
      if (data.peer !== this.id) {
        // message is not for us
        return;
      }

      if ((data.type == null)) {
        // invalid message
        return;
      }

      switch (data.type) {
        case 'from':
          if ((data.event == null) || (data.data == null)) {
            // invalid message
            return;
          }

          return this.emit(data.event, data.data);

        case 'peer_left':
          this.emit('left');
          return this.channel.removeListener('message', recv_msg);

        case 'peer_status':
          this.status = data.status;
          return this.emit('status_changed', this.status);
      }
    };

    this.channel.on('message', recv_msg);
  }


  send(event: string, data: any) {
    if (data == null) { data = {}; }
    return this.channel.send({
      type: 'to',
      peer: this.id,
      event,
      data
    });
  }
};


/**
 * Signaling for multi user chats
 *
 * The following messages are sent to the server:
 *
 *     // join the room. has to be sent before any other message.
 *     // response will be 'joined' on success
 *     // other peers in the room will get 'peer_joined'
 *     {
 *       "type": "join",
 *       "status": { .. status .. }
 *     }
 *
 *     // leave the room. server will close the connectino.
 *     {
 *       "type": "leave"
 *     }
 *
 *     // update status object
 *     // other peers will get 'peer_status'
 *     {
 *       "type": "status",
 *       "status": { .. status .. }
 *     }
 *
 *     // send message to a peer. will be received as 'from'
 *     {
 *       "type": "to",
 *       "peer": "peer_id",
 *       "event": "event_id",
 *       "data": { .. custom data .. }
 *     }
 *
 * The following messages are received form the server:
 *
 *     // joined the room. is the response to 'join'
 *     {
 *       "type": "joined",
 *       "id": "own_id",
 *       "peers": {
 *         "peer_id": { .. status .. }
 *       }
 *     }
 *
 *     // another peer joined the room.
 *     {
 *       "type": "peer_joined",
 *       "peer": "peer_id",
 *       "status": { .. status .. }
 *     }
 *
 *     // anosther peer updated its status object using 'status'
 *     {
 *       "type": "peer_status",
 *       "peer": "peer_id",
 *       "status": { .. status .. }
 *     }
 *
 *     // another peer left the room
 *     {
 *       "type": "peer_left",
 *       "peer": "peer_id"
 *     }
 *
 *     // message from another peer sent by 'to'
 *     {
 *       "type": "from",
 *       "peer": "peer_id",
 *       "event": "event_id",
 *       "data": { .. custom data .. }
 *     }
 *
 * The messages transmitted in the `to`/`from` messages are emitted as events in `MucSignalingPeer`
 *
 * @extends rtc.signaling.Signaling
 * @class rtc.signaling.MucSignaling
 *
 * @constructor
 * @param {rtc.signaling.Channel} channel The channel to the signaling server
 */
export class MucSignaling extends Signaling {

  channel: Channel;
  join_p: Promise<unknown>;
  connect_p?: Promise<unknown>;
  status: Record<string,any>;
  id?: string;

  /**
   * The id of the local peer. Only available after joining.
   * @property id
   * @type String
   */

  constructor(channel: Channel) {
      super();

    this.channel = channel;
    this.status = {};

    const join_d = new Deferred();
    this.join_p = join_d.promise;

    this.channel.on('closed', () => {
      return this.emit('closed');
    });

    this.channel.on('message', data => {
      let peer, status;
      if ((data.type == null)) {
        // invalid message
        return;
      }

      switch (data.type) {
        case 'joined':
          if ((data.peers == null)) {
            // invalid ...
            return;
          }

          for (let peer_id in data.peers) {
            status = data.peers[peer_id];
            peer = new MucSignalingPeer(this.channel, peer_id, status, false);
            this.emit('peer_joined', peer);
          }

          this.id = data.id;

          return join_d.resolve(null);

        case 'peer_joined':
          if ((data.peer == null)) {
            // invalid ...
            return;
          }

          peer = new MucSignalingPeer(this.channel, data.peer, data.status, true);
          return this.emit('peer_joined', peer);
      }
    });
  }


  connect() {
    if ((this.connect_p == null)) {
      this.connect_p = this.channel.connect().then(() => {
        return this.channel.send({
          type: 'join',
          status: this.status
        });
    }).then(() => {
        return this.join_p;
      });
    }

    return this.connect_p;
  }


  setStatus(status: Record<string,any>) {
    this.status = status;

    if (this.connect_p) {
      return this.connect_p.then(() => {
        return this.channel.send({
          type: 'status',
          status
        });
      });
    }
  }


  leave() {
    return this.channel.send({
      type: 'leave'
    }).then(() => {
      this.channel.close();
    });
  }
};
