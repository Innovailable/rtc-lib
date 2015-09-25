rtc = require('../../src/lib.coffee')

expect = require('chai').expect

describe 'rtc-lib', () ->
  it 'should contain all public interfaces', () ->
    expect(rtc).to.have.property('Room')
    expect(rtc).to.have.property('Peer')
    expect(rtc).to.have.property('RemotePeer')
    expect(rtc).to.have.property('LocalPeer')
    expect(rtc).to.have.property('PeerConnection')

    expect(rtc).to.have.property('MediaDomElement')

    expect(rtc).to.have.property('media')
    expect(rtc).to.have.property('compat')
