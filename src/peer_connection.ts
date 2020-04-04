/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { Deferred } from './internal/promise';
import { EventEmitter } from 'events';

import { Stream } from './stream';
import { DataChannel } from './data_channel';

export interface FingerprintInfo {
  type: string;
  hash: string;
}

export interface PeerConnectionFingerprints {
  local?: FingerprintInfo;
  remote?: FingerprintInfo;
}

function parseSdpFingerprint(sdp: RTCSessionDescription | null): FingerprintInfo | undefined {
  if(sdp == null) {
    return;
  }

  const matches = sdp.sdp.matchAll(/^a=fingerprint:(.*)$/gm);
  const fingerprints = new Set(Array.from(matches, (match) => match[1]));

  if(fingerprints.size === 0) {
    return;
  }

  if(fingerprints.size > 1) {
    console.log("multiple fingerprints, aborting");
    console.log(fingerprints);
    return;
  }

  const fingerprint = fingerprints.values().next().value;
  const [type, hash] = fingerprint.split(' ');

  return {
    type: type,
    hash: hash,
  }
}

/**
 * @module rtc
 */
/**
 * Wrapper around native RTCPeerConnection
 *
 * Provides events for new streams and data channels. Signaling information has
 * to be forwarded from events emitted by this object to the remote
 * PeerConnection.
 *
 * @class rtc.PeerConnection
 * @extends events.EventEmitter
 *
 * @constructor
 * @param {Boolean} offering True if the local peer should initiate the connection
 * @param {Object} options Options object passed on from `Room`
 */
export class PeerConnection extends EventEmitter {
  offering: boolean;
  // TODO
  options: any;
  no_gc_bugfix: Array<RTCDataChannel>;
  pc: RTCPeerConnection;
  connect_d: Deferred<null>;
  connected: boolean;
  // TODO
  signaling_pending: Array<any>;

  /**
   * New local ICE candidate which should be signaled to remote peer
   * @event ice_candiate
   * @param {Object} candidate The ice candidate
   */

  /**
   * New remote stream was added to the PeerConnection
   * @event stream_added
   * @param {rtc.Stream} stream The stream
   */

  /**
   * New DataChannel to the remote peer is ready to be used
   * @event data_channel_ready
   * @param {rtc.DataChannel} channel The data channel
   */

  /**
   * New offer or answer which should be signaled to the remote peer
   * @event signaling
   * @param {Object} obj The signaling message
   */

  /**
   * The PeerConnection was closed
   * @event closed
   */

  constructor(offering: boolean, options: Record<string,any>) {
      super();

    this.offering = offering;
    this.options = options;
    this.no_gc_bugfix = [];

    const ice_servers = [];

    if (this.options.stun != null) {
      ice_servers.push({urls: this.options.stun});
    }

    if (this.options.turn != null) {
      ice_servers.push(this.options.turn);
    }

    // TODO: STUN

    this.pc = new RTCPeerConnection({iceServers: ice_servers});

    this.connect_d = new Deferred();
    this.connected = false;

    this.connect_d.promise.catch(function() {});

    this.signaling_pending = [];

    // PeerConnection events

    this.pc.onicecandidate = event => {
      return this.emit('ice_candidate', event.candidate);
    };

    this.pc.ontrack = event => {
      return Array.from(event.streams).map((stream) =>
        this.emit('stream_added', new Stream(stream)));
    };

    this.pc.ondatachannel = event => {
      return this.emit('data_channel_ready', new DataChannel(event.channel));
    };

    //this.pc.onremovestream = function(event) {};
      // TODO

    this.pc.onnegotiationneeded = event => {
      // TODO
      return console.log('onnegotiationneeded called');
    };

    // PeerConnection states

    this.pc.oniceconnectionstatechange = () => {
      if (this.pc.iceConnectionState === 'failed') {
        return this._connectError(new Error("Unable to establish ICE connection"));
      } else if (this.pc.iceConnectionState === 'closed') {
        return this.connect_d.reject(new Error('Connection was closed'));
      } else if (['connected', 'completed'].includes(this.pc.iceConnectionState)) {
        return this.connect_d.resolve(null);
      }
    };

    this.pc.onsignalingstatechange = function(event) {};
  }
      //console.log(event)


  fingerprints(): PeerConnectionFingerprints {
    return {
      local: parseSdpFingerprint(this.pc.currentLocalDescription),
      remote: parseSdpFingerprint(this.pc.currentRemoteDescription),
    }
  }


  /**
   * Add new signaling information received from remote peer
   * @method signaling
   * @param {Object} data The signaling information
   *///
  signaling(data: RTCSessionDescriptionInit) {
    const sdp = new RTCSessionDescription(data);

    return this._setRemoteDescription(sdp).then(() => {
      if ((data.type === 'offer') && this.connected) {
        return this._answer();
      }
  }).catch(err => {
      return this._connectError(err);
    });
  }


  /**
   * Add a remote ICE candidate
   * @method addIceCandidate
   * @param {Object} desc The candidate
   */
  addIceCandidate(desc: RTCIceCandidateInit) {
    if ((desc != null ? desc.candidate : undefined) != null) {
      const candidate = new RTCIceCandidate(desc);
      return this.pc.addIceCandidate(candidate);
    }
    else {}
  }
      // TODO: end of ice trickling ... do something?


  /**
   * Returns the options for the offer/answer
   * @method _oaOptions
   * @private
   * @return {Object}
   */
  _oaOptions(): any {
    return {
      optional: [],
      mandatory: {
        OfferToReceiveAudio: true,
        OfferToReceiveVideo: true
      }
    };
  }


  /**
   * Set the remote description
   * @method _setRemoteDescription
   * @private
   * @param {Object} sdp The remote SDP
   * @return {Promise} Promise which will be resolved once the remote description was set successfully
   */
  _setRemoteDescription(sdp: RTCSessionDescriptionInit) {
    const description = new RTCSessionDescription(sdp);
    return this.pc.setRemoteDescription(sdp);
  }


  /**
   * Create offer, set it on local description and emit it
   * @method _offer
   * @private
   */
  _offer() {
    return this.pc.createOffer(this._oaOptions()).then(sdp => {
      return this._processLocalSdp(sdp);
  }).catch(err => {
      return this._connectError(err);
    });
  }


  /**
   * Create answer, set it on local description and emit it
   * @method _offer
   * @private
   */
  _answer() {
    return this.pc.createAnswer(this._oaOptions()).then(sdp => {
      return this._processLocalSdp(sdp);
  }).catch(err => {
      return this._connectError(err);
    });
  }


  /**
   * Set local description and emit it
   * @method _processLocalSdp
   * @private
   * @param {Object} sdp The local SDP
   * @return {Promise} Promise which will be resolved once the local description was set successfully
   */
  _processLocalSdp(sdp: RTCSessionDescriptionInit) {
    return this.pc.setLocalDescription(sdp).then(() => {
      const data  = {
        sdp: sdp.sdp,
        type: sdp.type
      };

      this.emit('signaling', data);
      return sdp;
    });
  }

  /**
   * Mark connection attempt as failed
   * @method _connectError
   * @private
   * @param {Error} err Error causing connection to fail
   */
  _connectError(err: Error) {
    // TODO: better errors
    this.connect_d.reject(err);
    return this.emit('error', err);
  }


  /**
   * Add local stream
   * @method addStream
   * @param {rtc.Stream} stream The local stream
   */
  addStream(stream: Stream) {
    return stream.stream.getTracks().map((track) =>
      this.pc.addTrack(track, stream.stream));
  }


  /**
   * Remove local stream
   * @method removeStream
   * @param {rtc.Stream} stream The local stream
   */
  removeSream(stream: Stream) {
    // TODO
    //return this.pc.removeStream(stream.stream);
  }


  /**
   * Add DataChannel. Will only actually do something if `offering` is `true`.
   * @method addDataChannel
   * @param {String} name Name of the data channel
   * @param {Object} desc Options passed to `RTCPeerConnection.createDataChannel()`
   */
  addDataChannel(name: string, options: RTCDataChannelInit) {
    if (this.offering) {
      const channel = this.pc.createDataChannel(name, options);

      // Don't let the channel be garbage collected
      // We only pass it on in onopen callback so the gc is not clever enough to let this live ...
      // https://code.google.com/p/chromium/issues/detail?id=405545
      // https://bugzilla.mozilla.org/show_bug.cgi?id=964092
      this.no_gc_bugfix.push(channel);

      return channel.onopen = () => {
        return this.emit('data_channel_ready', new DataChannel(channel));
      };
    }
  }


  /**
   * Establish connection with remote peer. Connection will be established once both peers have called this functio
   * @method connect
   * @return {Promise} Promise which will be resolved once the connection is established
   */
  connect() {
    if (!this.connected) {
      if (this.offering) {
        // we are starting the process
        this._offer();
      } else if (this.pc.signalingState === 'have-remote-offer') {
        // the other party is already waiting
        this._answer();
      }

      this.connected = true;
    }

    return Promise.resolve(this.connect_d.promise);
  }


  /**
   * Close the connection to the remote peer
   * @method close
   */
  close() {
    this.pc.close();
    return this.emit('closed');
  }
};

