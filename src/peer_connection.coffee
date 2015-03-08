events = require('events')

rtc = require('./lib')

class PeerConnection extends events.EventEmitter

  constructor: (@direct_channel, @offering, @options) ->
    @pc = rtc.compat.PeerConnection(iceOptions())

    # signaling

    @direct_channel.on 'request_connect', () =>
      @connect()


  iceOptions = () ->
    result = {}

    # ice

    iceOptions = results.iceServers =  []

    if @options.stun?
      result.push({url: @options.stun})

    # TODO: turn

    return result


  addStream: (stream) ->


  connect: () ->
    if @offering
      offer()
    else
      @direct_channel.send('request_connect')


  close: () ->
    @pc.close()
    @emit 'closed'

