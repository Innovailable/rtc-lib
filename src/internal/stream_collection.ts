import {Deferred} from './promise';
import { EventEmitter } from 'events';

import { Stream } from '../stream';
import { RemoteStreamDescription } from '../peer_connection';

/**
 * @module rtc.internal
 */
/**
 * Helper handling the mapping of streams for RemotePeer
 * @class rtc.internal.StreamCollection
 *
 * @constructor
 */
export class StreamCollection extends EventEmitter {
  streams: Record<string,Promise<Stream>>;
  _defers: Record<string,Deferred<Stream>>;
  _pending: Record<string,Stream>;
  _resolved: Record<string,Stream>;

  wait_d: Deferred<void>;
  wait_p: Promise<void>;

  /**
   * A new stream was added to the collection
   * @event steam_added
   * @param {String} name The user defined name of the stream
   * @param {Promise -> rtc.Stream} stream Promise to the stream
   */

  constructor() {
    /**
     * Contains the promises which will resolve to the streams
     * @property {Object} streams
     */

      super();
    this.streams = {};

    this._defers = {};
    this._pending = {};
    this._resolved = {};

    this.wait_d = new Deferred();
    this.wait_p = this.wait_d.promise;
  }


  /**
   * Set stream description and generate promises
   * @method update
   * @param streamNames {Object} An object mapping the stream ids to stream names
   */
  setRemote(data: RemoteStreamDescription): void {
    const streamNames = new Set(Object.values(data).map(([name, kind]) => name));

    // remove old streams

    for(const [name, stream_p] of Object.entries(this.streams)) {
      if (!streamNames.has(name)) {
        // remove

        delete this.streams[name];
	delete this._resolved[name];
        this.emit('stream_removed', name);

        // close/fail

        // TODO: this might be broken
        stream_p.then(stream => stream.stop());
      }
    }

    // update mappings

    for (const name of streamNames.values()) {
      // does stream exist?

      if (this.streams[name] == null) {
        // create stream promise

        const defer = new Deferred<Stream>();

        this.streams[name] = defer.promise;
        this._defers[name] = defer;

        this.emit('stream_added', name, defer.promise);
      }

      // do we adjust stream initialization?

      if (this._pending[name] != null && this._defers[name] != null) {
        // got it!

        const stream = this._pending[name];
        delete this._pending[name];

        this._defers[name].resolve(stream);
        delete this._defers[name];
      }
    }

    this.wait_d.resolve();
  }


  /**
   * Add stream to the collection and resolve promises waiting for it
   * @method resolve
   * @param {rtc.Stream} mediaStream
   */
  resolve(name: string, mediaStream: MediaStream): void {
    if(name in this._resolved) {
      const stream = this._resolved[name];

      if(mediaStream === stream.stream) {
        return;
      }

      stream.setStream(mediaStream);
      return;
    }

    const stream = new Stream(mediaStream);
    this._resolved[name] = stream;

    if (this._defers[name] != null) {
      // stream is expected

      this._defers[name].resolve(stream);
      delete this._defers[name];
    } else {
      // lets hope someone wants this later ...

      this._pending[name] = stream;
    }
  }


  /**
   * Gets a promise for a stream with the given name. Might be rejected after `update()`
   *
   * @method get
   * @param {String} name
   * @return {Promise} The promise for the `rtc.Stream`
   */
  get(name: string): Promise<Stream> {
    return this.wait_p.then(() => {
      if (this.streams[name] != null) {
        return this.streams[name];
      } else {
        throw new Error("Stream not offered");
      }
    });
  }
};

