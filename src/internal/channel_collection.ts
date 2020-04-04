import {Deferred} from './promise';
import {EventEmitter} from 'events';

import { DataChannel } from '../data_channel';

/**
 * @module rtc.internal
 */
/**
 * Helper which handles DataChannel negotiation for RemotePeer
 * @class rtc.internal.ChannelCollection
 */
export class ChannelCollection extends EventEmitter {
  channels: Record<string,Promise<DataChannel>>;
  defers: Record<string,Deferred<DataChannel>>;
  pending: Record<string,DataChannel>;

  wait_d: Deferred;
  wait_p: Promise<unknown>;

  local?: Record<string,RTCSessionDescriptionInit>;
  remote?: Record<string,RTCSessionDescriptionInit>;

  /**
   * A new data channel is available
   * @event data_channel_added
   * @param {String} name Name of the channel
   * @param {Promise -> rtc.Stream} stream Promise of the channel
   */

  constructor() {
      super();

    this.channels = {};

    this.defers = {};
    this.pending = {};

    this.wait_d = new Deferred();
    this.wait_p = this.wait_d.promise;
  }


  /**
   * Set the local channel description.
   * @method setLocal
   * @param {Object} data Object describing each offered DataChannel
   */
  setLocal(data: Record<string,RTCSessionDescriptionInit>): void {
    this.local = data;

    if (this.remote != null) {
      this._update();
    }
  }


  /**
   * Set the remote channel description.
   * @method setRemote
   * @param {Object} data Object describing each offered DataChannel
   */
  setRemote(data: Record<string,RTCSessionDescriptionInit>): void {
    this.remote = data;

    if (this.local != null) {
      this._update();
    }
  }


  /**
   * Matches remote and local descriptions and creates promises common DataChannels
   * @method _update
   * @private
   */
  _update(): void {
    // create channel promises
    // TODO: warn if config differs

    if(this.remote == null || this.local == null) {
      return;
    }

    for (const [name, config] of Object.entries(this.remote)) {
      if (this.local[name] != null) {
        if (this.channels[name] != null) {
          // nothing to do
          // should currently not happen

        } else if (this.pending[name] != null) {
          // use the pending channel

          const channel = this.pending[name];
          delete this.pending[name];

          this.channels[name] = Promise.resolve(channel);

          this.emit('data_channel_added', name, this.channels[name]);

        } else {
          // create a defer for the channel

          const defer = new Deferred<DataChannel>();

          this.channels[name] = defer.promise;
          this.defers[name] = defer;

          this.emit('data_channel_added', name, this.channels[name]);
        }

      } else {
        // TODO: better warning
        console.log("DataChannel offered by remote but not by local");
      }
    }

    // notice @local only channels

    for (const name in this.local) {
      if (this.remote[name] == null) {
        console.log("DataChannel offered by local but not by remote");
      }
    }

    // we should be able to get channels from now on

    this.wait_d.resolve(null);
  }


  /**
   * Resolves promises waiting for the given DataChannel
   * @method resolve
   * @param {DataChannel} channel The new channel
   */
  resolve(channel: DataChannel): void {
    const label = channel.label();

    if (this.defers[label] != null) {
      this.defers[label].resolve(channel);
      delete this.defers[label];
    } else {
      this.pending[label] = channel;
    }
  }


  /**
   * Get a promise to a DataChannel. Will resolve if DataChannel was offered and gets initiated. Might reject after remote and local description are processed.
   * @method get
   * @param {String} name The label of the channel to get
   * @return {Promise -> DataChannel} Promise for the DataChannel
   */
  get(name: string): Promise<DataChannel> {
    return this.wait_p.then(() => {
      if (this.channels[name] != null) {
        return this.channels[name];
      } else {
        throw new Error("DataChannel not negotiated");
      }
    });
  }
};
