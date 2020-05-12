import { Deferred } from './internal/promise';
import { EventEmitter } from 'events';

import { Stream, StreamTrackType } from './stream';
import { DataChannel } from './data_channel';
import { StreamTransceiverFactory } from './types';

export interface FingerprintInfo {
  type: string;
  hash: string;
}

export interface PeerConnectionFingerprints {
  local?: FingerprintInfo;
  remote?: FingerprintInfo;
}

export type RemoteStreamDescription = Record<string,[string,'audio'|'video']>;

export interface AnnotateSessionDescription extends RTCSessionDescriptionInit {
  streams: RemoteStreamDescription;
}

export interface TransceiverData {
  kind: StreamTrackType;
  transceiver: RTCRtpTransceiver;
}

export type TransceiverCleanup = () => void;

interface StreamData {
  transceivers: ReadonlyArray<TransceiverData>;
  cleanups: ReadonlyArray<TransceiverCleanup>;
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
  current_streams = new Map<string,StreamData>();
  pending_streams = new Map<string,ReadonlyArray<StreamTransceiverFactory>>();
  remote_streams?: RemoteStreamDescription;
  renegotiate = false;

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
      let stream = event.streams[0];

      if(this.remote_streams == null) {
        console.log('Got track without remote streams');
        return;
      }

      const mid = event.transceiver.mid!;
      const streamName = this.remote_streams[mid][0];

      // build a stream if it is not build for us
      // workaround for firefox missing `transceiver.sender.setStreams()`
      // TODO remove when firefox is fixed

      if(stream == null) {
        // create a stream to fire

        stream = new MediaStream([event.track]);

        // add other tracks we know

        for(const transceiver of this.pc.getTransceivers()) {
          const track = transceiver.receiver.track;

          if(track == null) {
            continue;
          }

          const trackStreamName = this.remote_streams[transceiver.mid!][0];

          if(streamName === trackStreamName) {
            stream.addTrack(track);
          }
        }
      }

      this.emit('stream_added', stream, streamName);
    };

    this.pc.ondatachannel = event => {
      this.emit('data_channel_ready', new DataChannel(event.channel));
    };

    this.pc.onnegotiationneeded = event => {
      if(this.pc.signalingState === 'stable') {
        this.negotiate();
      } else {
        this.renegotiate = true;
      }
    };

    this.pc.onsignalingstatechange = event => {
      if(this.pc.signalingState === 'stable' && this.renegotiate) {
        this._offer();
      }
    }

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
  async signaling(data: AnnotateSessionDescription) {
    const sdp = new RTCSessionDescription(data);

    try {
      if(data.type === 'offer' && this.pc.signalingState !== 'stable') {
        if(this.offering) {
          return;
        }

        this.remote_streams = data.streams;

        await Promise.all([
          this.pc.setLocalDescription({ type: 'rollback' }),
          this.pc.setRemoteDescription(sdp),
        ]);
      } else {
        this.remote_streams = data.streams;
        await this.pc.setRemoteDescription(sdp);
      }

      if ((data.type === 'offer') && this.connected) {
        this._answer();
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
      this._createTransceivers();
      this.renegotiate = false;
      const sdp = await this.pc.createOffer(this._oaOptions());
      await this._processLocalSdp(sdp);
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
      this._mapTransceivers();
      this.renegotiate = false;
      const sdp = await this.pc.createAnswer(this._oaOptions());
      await this._processLocalSdp(sdp);
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

    const streams: Record<string,[string,'audio'|'video']>  = {};

    for(const [name, { transceivers }] of this.current_streams.entries()) {
      for(const { kind, transceiver } of transceivers) {
        if(transceiver.mid == null) {
          console.log('Transceiver without mid encountered');
          continue;
        }

        streams[transceiver.mid] = [name, kind];
      }
    }

    const data: AnnotateSessionDescription = {
      sdp: sdp.sdp,
      type: sdp.type,
      streams,
    };

    this.emit('signaling', data);
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


  setStreams(new_streams: Map<string,ReadonlyArray<StreamTransceiverFactory>>) {
    // remove old streams

    this.current_streams.forEach(({ transceivers, cleanups }, stream) => {
      if(new_streams.has(stream)) {
        return;
      }

      for(const { transceiver } of transceivers) {
        transceiver.stop();
      }

      for(const cleanup of cleanups) {
        cleanup();
      }

      this.current_streams.delete(stream);
    });

    // add new streams

    new_streams.forEach((factories, stream) => {
      if(this.current_streams.has(stream)) {
        return;
      }

      this.pending_streams.set(stream, factories);
    });
  }


  _mapTransceivers() {
    const usedMids = new Set<string>();
    const transceivers = this.pc.getTransceivers();

    const claimTransceiver = (searchName: string, searchKind: StreamTrackType) => {
      if(this.remote_streams == null) {
        return;
      }

      const match = Object.entries(this.remote_streams).find(([mid, [curName, curKind]]) => {
        return searchName === curName && searchKind === curKind && !usedMids.has(mid);
      });

      if(match == null) {
        return;
      }

      const mid = match[0];

      usedMids.add(mid);

      return this.pc.getTransceivers().find((transceiver) => transceiver.mid === mid);
    };

    for(const [name, factories] of this.pending_streams.entries()) {
      const transceivers = Array<TransceiverData>();
      const cleanups = Array<TransceiverCleanup>();

      for(const factory of factories) {
        const cleanup = factory((track, init) => {
          const kind = (typeof track === 'string' ? track : track.kind) as StreamTrackType;

          let transceiver = claimTransceiver(name, kind);

          if(transceiver) { 
            if(typeof track !== 'string') {
              transceiver.sender.replaceTrack(track);
            }

            if(init?.streams != null) {
              transceiver.sender.setStreams?.apply(transceiver.sender, init.streams);
            }

            if(init?.direction) {
              transceiver.direction = init.direction;
            }

            if(init?.sendEncodings) {
              const parameters = transceiver.sender.getParameters();
              transceiver.sender.setParameters({
                ...parameters,
                encodings: init.sendEncodings,
              });
            }
          } else {
            // TODO find a way to let devs handle this kind of error
            // will it ever trigger outside of application error?
            console.log('Unable to match transceiver. The setup of tracks/transceivers has to be symetrical between peers.');
            transceiver = this.pc.addTransceiver(track, init);
          }

          transceivers.push({ kind, transceiver });

          return transceiver;
        });

        if(cleanup != null) {
          cleanups.push(cleanup);
        }
      }

      this.current_streams.set(name, { transceivers, cleanups });
    }

    this.pending_streams = new Map();
  }


  _createTransceivers() {
    for(const [name, factories] of this.pending_streams.entries()) {
      const transceivers = Array<TransceiverData>();
      const cleanups = Array<TransceiverCleanup>();

      for(const factory of factories) {
        const cleanup = factory((track, init) => {
          const kind = (typeof track === 'string' ? track : track.kind) as StreamTrackType;
          const transceiver = this.pc.addTransceiver(track, init);

          transceivers.push({ kind, transceiver });

          return transceiver;
        });

        if(cleanup != null) {
          cleanups.push(cleanup);
        }
      }

      this.current_streams.set(name, { transceivers, cleanups });
    }

    this.pending_streams = new Map();
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
        this._createTransceivers();
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

