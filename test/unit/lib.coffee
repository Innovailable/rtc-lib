rtc = require('../../src/lib.coffee')

describe 'rtc-lib', () ->
  it 'should contain all public interfaces', () ->
    rtc.should.have.property('Room')
    rtc.should.have.property('Peer')
    rtc.should.have.property('RemotePeer')
    rtc.should.have.property('LocalPeer')
    rtc.should.have.property('PeerConnection')

    rtc.should.have.property('MediaDomElement')

    rtc.should.have.property('compat')
