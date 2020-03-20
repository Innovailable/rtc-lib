/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const rtc = require('../../src/index');

describe('rtc-lib', () => it('should contain all public interfaces', function() {
  rtc.should.have.property('Room');
  rtc.should.have.property('Peer');
  rtc.should.have.property('RemotePeer');
  rtc.should.have.property('LocalPeer');
  rtc.should.have.property('PeerConnection');

  rtc.should.have.property('MediaDomElement');
}));
