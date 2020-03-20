/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import {Deferred} from './promise';
import { EventEmitter } from 'events';

import { Stream } from '../stream';

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
  _waiting: Record<string,string>;
  _pending: Record<string,Stream>;

  wait_d: Deferred;
  wait_p: Promise<unknown>;

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
    this._waiting = {};
    this._pending = {};

    this.wait_d = new Deferred();
    this.wait_p = this.wait_d.promise;
  }


  /**
   * Set stream description and generate promises
   * @method update
   * @param data {Object} An object mapping the stream ids to stream names
   */
  update(data: Record<string,string>): void {
    let name;
    const members = [];
    this._waiting = {};

    // remove old streams

    for(const [name, stream_p] of Object.entries(this.streams)) {
      if ((data[name] == null)) {
        // remove

        delete this.streams[name];
        this.emit('stream_removed', name);

        // close/fail

        // TODO: this might be broken
        stream_p.then(stream => stream.stop());
      }
    }

    // update mappings

    for (name in data) {
      // does stream exist?

      const id = data[name];
      if ((this.streams[name] == null)) {
        // create stream promise

        const defer = new Deferred<Stream>();

        this.streams[name] = defer.promise;
        this._defers[name] = defer;

        this.emit('stream_added', name, defer.promise);
      }

      // do we adjust stream initialization?

      if (this._defers[name] != null) {
        if (this._pending[id] != null) {
          // got it!

          const stream = this._pending[id];
          delete this._pending[id];

          this._defers[name].resolve(stream);
          delete this._defers[name];

        } else {
          // add waiting mapping

          this._waiting[id] = name;
        }
      }
    }

    this.wait_d.resolve(null);
  }


  /**
   * Add stream to the collection and resolve promises waiting for it
   * @method resolve
   * @param {rtc.Stream} stream
   */
  resolve(stream: Stream): void {
    let id = stream.id();

    // streams from Chrome to Firefox are coming in with id set to 'default' ...
    if (id === 'default') {
      if ((Object.keys(this.streams).length === 1) && (Object.keys(this._waiting).length === 1)) {
        console.log("Working around incompatibility between Firefox and Chrome concerning stream identification");
        id = Object.keys(this._waiting)[0];
      } else {
        console.log("Unable to work around incompatibility between Firefox and Chrome concerning stream identification");
      }
    }

    if (this._waiting[id] != null) {
      // stream is expected

      const name = this._waiting[id];
      delete this._waiting[id];

      this._defers[name].resolve(stream);
      delete this._defers[name];

    } else {
      // lets hope someone wants this later ...

      this._pending[id] = stream;
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

