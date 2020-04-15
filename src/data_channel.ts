/*
 * decaffeinate suggestions:
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { Deferred } from './internal/promise';
import { EventEmitter } from 'events';

/**
 * @module rtc
 */
/**
 * A wrapper for RTCDataChannel. Used to transfer custom data between peers.
 * @class rtc.DataChannel
 *
 * @constructor
 * @param {RTCDataChannel} channel The wrapped native data channel
 * @param {Number} [max_buffer] The size of the send buffer after which we will delay sending
 */
export class DataChannel extends EventEmitter {
  channel: RTCDataChannel;
  max_buffer: number;
  _connected: boolean;
  // TODO
  _connect_queue: Array<any>;
  _send_buffer: Array<any>;

  /**
   * A new messages was received. Triggers only after `connect()` was called
   * @event message
   * @param {ArrayBuffer} data The data received
   */

  /**
   * The channel was closed
   * @event closed
   */

  constructor(channel: RTCDataChannel, max_buffer: number = 1024*10) {
    super();

    this.channel = channel;
    this.max_buffer = max_buffer;
    this._connected = false;
    this._connect_queue = [];

    // buffer management

    this._send_buffer = [];

    // make sure we are using arraybuffer

    this.channel.binaryType = 'arraybuffer';

    // event handling

    this.channel.onmessage = event => {
      if (!this._connected) {
        this._connect_queue.push(event.data);
      } else {
        this.emit('message', event.data);
      }
    };

    this.channel.onclose = () => {
      this.emit('closed');
    };

    // TODO: what to do with this?
    this.channel.onerror = err => {
      this.emit('error', err);
    };
  }


  /**
   * Connect to the DataChannel. You will receive messages and will be able to send after calling this.
   * @method connect
   * @return {Promise} Promise which resolves as soon as the DataChannel is open
   */
  connect(): Promise<void> {
    if (this._connected) {
      return Promise.resolve();
    }

    this._connected = true;

    for (let data of this._connect_queue) {
      this.emit('message', data);
    }

    delete this._connect_queue;

    return Promise.resolve();
  }


  close(): Promise<void> {
    this.channel.close();
    return Promise.resolve();
  }


  /**
   * The label of the DataChannel used to distinguish multiple channels
   * @method label
   * @return {String} The label
   */
  label(): string {
    return this.channel.label;
  }


  /**
   * Send data to the peer through the DataChannel
   * @method send
   * @param data The data to be transferred
   * @return {Promise} Promise which will be resolved when the data was passed to the native data channel
   *///
  send(data: any): Promise<void> {
    if (!this._connected) {
      this.connect();
      console.log("Sending without being connected. Please call connect() on the data channel to start using it.");
    }

    const defer = new Deferred<void>();
    this._send_buffer.push([data, defer]);

    if (this._send_buffer.length === 1) {
      this.actualSend();
    }

    return defer.promise;
  }


  /**
   * Method which actually sends the data. Implements buffering
   * @method _actualSend
   * @private
   */
  private actualSend(): void {
    let data, defer;
    if (this.channel.readyState === 'open') {
      // actual sending
      // TODO: help user with max package size?
      while (this._send_buffer.length) {
        // should we keep sending right now?
        if (this.channel.bufferedAmount >= this.max_buffer) {
          // TODO: less cpu heavy timeout value?
          setTimeout(this.actualSend.bind(this), 1);
        }

        [data, defer] = this._send_buffer[0];

        try {
          this.channel.send(data);
        } catch (error) {
          // TODO: less cpu heavy and fail after some time?
          // TODO: do not loop endless on fatal errors which do not close the channel
          setTimeout(this.actualSend.bind(this), 1);
        }

        defer.resolve();

        this._send_buffer.shift();
      }

    } else {
      // fail the send promises
      while (this._send_buffer.length) {
	[data, defer] = this._send_buffer.shift();
	defer.reject(new Error("DataChannel closed"));
      }
    }
  }
};
