/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { EventEmitter } from 'events';
import { Stream } from './stream';
import { DataChannel } from './data_channel';

/**
 * @module rtc
 */
/**
 * A user in the room
 * @class rtc.Peer
 */
export class Peer extends EventEmitter {
  /**
   * The status of the peer has changed
   * @event status_changed
   * @param {Object} status The new status object
   */
  
  static DEFAULT_CHANNEL = 'data';
  static DEFAULT_STREAM = 'stream';


  /**
   * Get a value of the status object
   * @method status
   * @param {String} key The key 
   * @return The value
   */
  status(key: string, value?: string) { throw new Error("Not implemented"); }

  isLocal(): boolean { throw new Error("Not implemented"); }

  stream(name: string = Peer.DEFAULT_STREAM): Promise<Stream> { throw new Error("Not implemented"); }
}
