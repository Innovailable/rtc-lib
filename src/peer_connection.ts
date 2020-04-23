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
  connect_d: Deferred<void>;
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
      this.emit('ice_candidate', event.candidate);
    };

    this.pc.ontrack = event => {
      event.streams.map((stream) =>
        this.emit('stream_added', new Stream(stream)));
    };

    this.pc.ondatachannel = event => {
      this.emit('data_channel_ready', new DataChannel(event.channel));
    };

    //this.pc.onremovestream = function(event) {};
      // TODO

    //this.pc.onnegotiationneeded = event => {
      //// TODO
      //console.log('onnegotiationneeded called ...');
    //};

    // PeerConnection states

    this.pc.oniceconnectionstatechange = () => {
      if (this.pc.iceConnectionState === 'failed') {
        this._connectError(new Error("Unable to establish ICE connection"));
      } else if (this.pc.iceConnectionState === 'closed') {
        this.connect_d.reject(new Error('Connection was closed'));
      } else if (['connected', 'completed'].includes(this.pc.iceConnectionState)) {
        this.connect_d.resolve();
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
   */
  async signaling(data: RTCSessionDescriptionInit) {
    const sdp = new RTCSessionDescription(data);

    try {
      if(data.type === 'offer' && this.pc.signalingState !== 'stable') {
        if(this.offering) {
          return;
        }

        await Promise.all([
          this.pc.setLocalDescription({ type: 'rollback' }),
          this.pc.setRemoteDescription(sdp),
        ]);
      } else {
        await this.pc.setRemoteDescription(sdp);
      }

      if ((data.type === 'offer') && this.connected) {
        return this._answer();
      }
    } catch(err) {
      this._connectError(err);
    }
  }


  /**
   * Add a remote ICE candidate
   * @method addIceCandidate
   * @param {Object} desc The candidate
   */
  addIceCandidate(desc: RTCIceCandidateInit) {
    if (desc?.candidate != null) {
      const candidate = new RTCIceCandidate(desc);
      this.pc.addIceCandidate(candidate);
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
   * Create offer, set it on local description and emit it
   * @method _offer
   * @private
   */
  async _offer() {
    try {
      const sdp = await this.pc.createOffer(this._oaOptions());
      return this._processLocalSdp(sdp);
    } catch(err) {
      this._connectError(err);
    }
  }


  /**
   * Create answer, set it on local description and emit it
   * @method _offer
   * @private
   */
  async _answer() {
    try {
      const sdp = await this.pc.createAnswer(this._oaOptions());
      return this._processLocalSdp(sdp);
    } catch(err) {
      this._connectError(err);
    }
  }


  /**
   * Set local description and emit it
   * @method _processLocalSdp
   * @private
   * @param {Object} sdp The local SDP
   * @return {Promise} Promise which will be resolved once the local description was set successfully
   */
  async _processLocalSdp(sdp: RTCSessionDescriptionInit) {
    await this.pc.setLocalDescription(sdp);

    const data  = {
      sdp: sdp.sdp,
      type: sdp.type
    };

    this.emit('signaling', data);
    return sdp;
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
    this.emit('error', err);
  }


  /**
   * Add local stream
   * @method addStream
   * @param {rtc.Stream} stream The local stream
   */
  addStream(stream: Stream) {
    for(const track of stream.stream.getTracks()) {
      this.pc.addTrack(track, stream.stream);
    }
  }


  /**
   * Remove local stream
   * @method removeStream
   * @param {rtc.Stream} stream The local stream
   */
  removeSream(stream: Stream) {
    // TODO
    //this.pc.removeStream(stream.stream);
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

      channel.onopen = () => {
        this.emit('data_channel_ready', new DataChannel(channel));
      };
    }
  }


  negotiate() {
    if(!this.connected) {
      return;
    }

    this._offer();
  }


  /**
   * Establish connection with remote peer. Connection will be established once both peers have called this functio
   * @method connect
   * @return {Promise} Promise which will be resolved once the connection is established
   */
  connect(): Promise<void> {
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
    this.emit('closed');
  }
};

