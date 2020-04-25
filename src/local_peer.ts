import { Peer } from './peer';
import { Stream } from './stream';
import { StreamInitData, StreamTransceiverFactoryArray } from './types';
import { sanitizeStreamTransceivers } from './helper';

/**
 * @module rtc
 */
/**
 * Represents the local user of the room
 * @class rtc.LocalPeer
 * @extends rtc.Peer
 *
 * @constructor
 */
export class LocalPeer extends Peer {
  streams: Record<string,StreamInitData>;
  // TODO
  channels: Record<string,RTCDataChannelInit>;
  _status: Record<string,string>;

  constructor() {
    /**
     * Contains promises of the local streams offered to all remote peers
     * @property streams
     * @type Object
     */
      super();

    this.streams = {};

    /**
     * Contains all DataChannel configurations negotiated with all remote peers
     * @property channels
     * @type Object
     */
    this.channels = {};

    this._status = {};
  }


  /**
   * Get an item of the status transferred to all remote peers
   * @method status
   * @param {String} key The key of the value. Will return
   * @return The value associated with the key
   */
  /**
   * Set an item of the status transferred to all remote peers
   * @method status
   * @param {String} key The key of the value. Will return
   * @param value The value to store
   */
  status(key: string, value?: any) {
    if (value != null) {
      this._status[key] = value;
      this.emit('status_changed', this._status);
    } else {
      this._status[key];
    }
  }


  /**
   * Add data channel which will be negotiated with all remote peers
   * @method addDataChannel
   * @param {String} [name='data'] Name of the data channel
   * @param {Object} [desc={ordered: true}] Options passed to `RTCDataChannel.createDataChannel()`
   */
  addDataChannel(name: string, desc: Record<string,any>) {
    if (typeof name !== 'string') {
      desc = name;
      name = Peer.DEFAULT_CHANNEL;
    }

    if (desc == null) {
      // TODO: default handling
      desc = {
        ordered: true
      };
    }

    this.channels[name] = desc;
    this.emit('configuration_changed');
  }


  /**
   * Add local stream to be sent to all remote peers
   * @method addStream
   * @param {String} [name='stream'] Name of the stream
   * @param {Promise -> rtc.Stream | rtc.Stream | Object} stream The stream, a promise to the stream or the configuration to create a stream with `rtc.Stream.createStream()`
   * @return {Promise -> rtc.Stream} Promise of the stream which was added
   */
  addStream(obj: Stream | Promise<Stream> | MediaStreamConstraints): Promise<Stream>;
  addStream(name: string, obj: Stream | Promise<Stream> | MediaStreamConstraints): Promise<Stream>

  addStream(a: any, b?: any, c?: any): Promise<Stream> {
    let name: string;
    let obj: Stream | Promise<Stream> | MediaStreamConstraints;
    let transceivers: StreamTransceiverFactoryArray;

    // name can be omitted ... once
    if (typeof a === 'string') {
      name = a;
      obj = b;
      transceivers = sanitizeStreamTransceivers(c);
    } else {
      name = Peer.DEFAULT_STREAM;
      obj = a;
      transceivers = sanitizeStreamTransceivers(b);
    }

    // helper to actually save stream
    const saveStream = (stream_p: Promise<Stream>) => {
      // TODO: collision detection?
      this.streams[name] = {
        stream: stream_p,
        transceivers,
      };
      this.emit('configuration_changed');
      this.emit('streams_changed');
      this.emit('stream_added', stream_p);
      return stream_p;
    };

    if ('then' in obj) {
      // it is a promise
      return saveStream(obj as Promise<Stream>);
    } else if (obj instanceof Stream) {
      // it is the actual stream, turn into promise
      return saveStream(Promise.resolve(obj));
    } else {
      // we assume we can pass it on to create a stream
      const stream_p = Stream.createStream(obj);
      return saveStream(stream_p);
    }
  }


  removeStream(name: string = Peer.DEFAULT_STREAM) {
    delete this.streams[name];
    this.emit('configuration_changed');
    this.emit('streams_changed');
    // TODO remove event?
  }


  /**
   * Get local stream
   * @method stream
   * @param {String} [name='stream'] Name of the stream
   * @return {Promise -> rtc.Stream} Promise of the stream
   */
  stream(name: string = Peer.DEFAULT_STREAM) {
    if (name == null) { name = Peer.DEFAULT_STREAM; }
    return this.streams[name].stream;
  }


  /**
   * Checks whether the peer is the local peer. Returns always `true` on this
   * class.
   * @method isLocal
   * @return {Boolean} Returns `true`
   */
  isLocal() {
    return true;
  }
};
