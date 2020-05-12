/*
 * decaffeinate suggestions:
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { EventEmitter } from 'events';
import StrictEventEmitter from 'strict-event-emitter-types';
import { Stream } from './stream';

export type TypedEventEmitter<T> = StrictEventEmitter<EventEmitter,T>;

export type StreamTransceiverCleanup = () => void;
export type StreamTransceiverFactoryCb = RTCPeerConnection["addTransceiver"];
export type StreamTransceiverFactory = (create: StreamTransceiverFactoryCb) => (void | StreamTransceiverCleanup);
export type StreamTransceiverFactoryArray = StreamTransceiverFactory[];

export interface StreamInitData {
  stream: Promise<Stream>;
  transceivers: StreamTransceiverFactoryArray;
}

/**
 * @module rtc.signaling
 */

export interface SignalingEvents<SP extends SignalingPeer> {
  peer_joined: (peer: SP) => void;
  closed: () => void;
};

/**
 * Concept of a class implementing signaling. Might use a `rtc.signaling.Channel` to abstract the connection to the server.
 *
 * You do not have to extend this claass, just implement the functionality.
 *
 * @extends events.EventEmitter
 * @class rtc.signaling.Signaling
 */
export interface Signaling<SP extends SignalingPeer = SignalingPeer> extends TypedEventEmitter<SignalingEvents<SP>> {
  // TODO hack used for typing, ignore for now, remove when we got a better idea
  __peer?: SP;

  /**
   * A new peer joined the room
   * @event peer_joined
   * @param {rtc.signaling.SignalingPeer} peer The new peer
   */

  /**
   * The connection to the signaling server was closed
   * @event closed
   */

  /**
   * Establishes the connection with the signaling server
   * @method connect
   * @return {Promise} Promise which is resolved when the connection is established
   */
  connect() : Promise<void>;

  /**
   * Closes the connection to the signaling server
   * @method close
   */
  close(): void;

  /**
   * Sets the local status object and broadcasts the change to the peers
   * @method setStatus
   * @param {Object} obj New status object
   */
  setStatus(obj: Record<string,any>): Promise<void>;
};


export interface SignalingPeerEvents {
  left: () => void;
  signaling: (data: any) => void;
  message: (data: any) => void;
  ice_candidate: (data: any) => void;
  status_changed: (status: Record<string,any>) => void;
};

/**
 * Concept of a class implementing a signaling connection to a peer.
 *
 * You do not have to extend this class, just implement the functionality.
 *
 * @extends events.EventEmitter
 * @class rtc.signaling.SignalingPeer
 */
export interface SignalingPeer extends TypedEventEmitter<SignalingPeerEvents> {
  /**
   * The remote peer left the room
   * @event left
   */

  /**
   * Received a message from the remote peer
   * @event message
   * @param {String} event ID of the event
   * @param {Obejct} data Payload of the event
   */

  /**
   * The status object of the remote peer was updated
   * @event status_changed
   * @param {Object} status The new status
   */

  /**
   * The status object of the remote peer
   * @property status
   * @type Object
   * @readonly
   */
  status: Record<string,any>

  /**
   * Whether the local user was in the room before the remote user (used to determine which peer will initiate the connection)
   * @property first
   * @type Boolean
   * @readonly
   */
  first: boolean;

  id: string;

  /**
   * Sends the event with the given payload to the remote peer
   * @method send
   * @param {String} event The id of the event
   * @param {Object} data The payload of the event
   * @return {Promise} Promise which will be resolved once the message is sent
   */
  send(event: string, data: any): Promise<void>;
};

export interface ChannelEvents {
  message: (data: any) => void;
  closed: () => void;
}

/**
 * Concept of a class implementing a signaling channel. Might be used by signaling implementations to connect to a signaling server.
 *
 * You do not have to extend this class, just implement the functionality.
 *
 * @extends events.EventEmitter
 * @class rtc.signaling.Channel
 */
export interface Channel extends TypedEventEmitter<ChannelEvents> {

  /**
   * A message was received from the signaling server
   * @event message
   * @param {Object} msg The received message
   */

  /**
   * The connection to the signaling server was closed
   * @event closed
   */

  /**
   * Establishes the connection with the signaling server
   * @method connect
   * @return {Promise} Promise which is resolved when the connection is established
   */
  connect(): Promise<void>;

  /**
   * Sends a message to the signaling server
   * @method send
   * @param {Object} msg The message to send
   * @return {Promise} Promise which is resolved when the message is sent
   */
  send(msg: any): Promise<void>;

  /**
   * Closes the connection to the signaling server
   * @method close
   */
  close(): Promise<void>;
};
