{DataChannel} = require('../../../src/data_channel')

# receives all sent data
class EchoChannel

  constructor: (@label) ->
    @bufferedAmount = 0
    @readyState = 'open'

  send: (data) ->
    @onmessage({data: data})

# receives all sent data with half of the send()s failing
class DisruptedChannel

  constructor: (@label) ->
    @bufferedAmount = 0
    @readyState = 'open'
    @error_toggle = false

  send: (data) ->
    @error_toggle = not @error_toggle

    if @error_toggle
      throw new Error("not now!")
    else
      @onmessage({data: data})

# signals error after some attempts
class FailingChannel

  constructor: (@label, @attempts=20) ->
    @bufferedAmount = 0
    @readyState = 'open'

  send: (data) ->
    @attempts -= 1

    if @attempts == 0
      @readyState = 'closed'
      @onerror(new Error("We failed"))

    throw new Error("not now!")

# sends some data and checks whether it is received
simple_echo_test = (channel, send_data=['test', 'me', 'please']) ->
  recv_data = []

  channel.on 'message', (data) -> recv_data.push(data)

  promises = []

  return channel.connect().then () ->
    for data in send_data
      p = channel.send(data)
      promises.push(p)

    return Promise.all(promises)
  .then () ->
    return recv_data
  .should.become(send_data)


describe 'DataChannel', () ->
  describe 'Sending and receiving', () ->
    echo = null
    channel = null

    beforeEach () ->
      echo = new EchoChannel("test")
      channel = new DataChannel(echo)

    it 'should be able to send and receive', () ->
      return simple_echo_test(channel)

    it 'should receive data sent before being conencted', () ->
      recv_data = []

      echo.send("a")

      channel.on 'message', (data) -> recv_data.push(data)

      echo.send("b")

      return channel.connect().then () ->
        echo.send("c")
        return recv_data
      .should.become(["a", "b", "c"])


  describe 'Handling RTCDataChannel errors', () ->

    it 'should retry on send errors', () ->
      channel = new DataChannel(new DisruptedChannel("test"))
      return simple_echo_test(channel)

    it 'should fail when channel is closed because of error', () ->
      rtc = new FailingChannel("test")
      channel = new DataChannel(rtc)

      return channel.connect().then () ->
        promises = []

        for data in ["a", "b", "c"]
          promise = channel.send(data)
          promises.push(promise.should.be.rejectedWith(Error))

        return Promise.all(promises)

