/*
 * decaffeinate suggestions:
 * DS001: Remove Babel/TypeScript constructor workaround
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { EventEmitter } from 'events';
import { Channel } from '../types';

/**
 * @module rtc.signaling
 */
/**
 * @class rtc.signaling.WebSocketChannel
 * @extends rtc.signaling.Channel
 */
export class WebSocketChannel extends EventEmitter implements Channel {

  address: string;
  connect_p?: Promise<void>;
  socket?: WebSocket;

  constructor(address: string, ...parts: string[]) {
      super();

    this.address = address;
    if (parts.length > 0) {
      // remove trailing slashes
      while (this.address.endsWith('/')) {
        this.address = this.address.substr(0, this.address.length - 1);
      }

      // add parts
      for (let part of Array.from(parts)) {
        this.address += '/' + encodeURIComponent(part);
      }
    }
  }


  connect() {
    if ((this.connect_p == null)) {
      this.connect_p = new Promise((resolve, reject) => {
        const socket = new WebSocket(this.address);

        socket.onopen = () => {
          this.socket = socket;
          return resolve();
        };

        socket.onerror = err => {
          // TODO: better error handling
          // TODO: handle errors after connecting
          delete this.socket;
          return reject(new Error("Unable to connect to socket"));
        };

        socket.onmessage = event => {
          let data;
          try {
            data = JSON.parse(event.data);
          } catch (error) {
            return;
          }

          return this.emit('message', data);
        };

        return socket.onclose = () => {
          return this.emit('closed');
        };
      });
    }

    return this.connect_p;
  }


  send(msg: any) {
    if (this.socket != null) {
      // TODO: maybe do fancy buffer handling like DataChannel
      try {
        this.socket.send(JSON.stringify(msg));
        return Promise.resolve();
      } catch (err) {
        return Promise.reject(err);
      }
    } else {
      return Promise.reject(new Error("Trying to send on WebSocket without being connected"));
    }
  }


  close() {
    if (this.socket != null) {
      try {
        this.socket.close();
        return Promise.resolve();
      } catch (err) {
        return Promise.reject(err);
      }
    } else {
      return Promise.reject(new Error("Trying to close WebSocket without being connected"));
    }
  }
};
