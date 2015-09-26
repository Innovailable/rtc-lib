{DataChannel} = require('../../src/data_channel')

expect = require('chai').expect

# receives all sent data
class EchoChannel

  constructor: () ->
    @bufferedAmount = 0
    @readyState = 'open'

  send: (data) ->
    @onmessage({data: data})

# sends some data and checks whether it is received
simple_echo_test = (channel, send_data=['test', 'me', 'please']) ->
  recv_data = []

  channel.on 'message', (data) -> recv_data.push(data)

  return channel.connect().then () ->
    promises = []

    for data in send_data
      p = channel.send(data)
      promises.push(p)

    return Promise.all(promises)
  .then () ->
    recv_data.should.deep.equal(send_data)


describe 'DataChannel', () ->
  describe 'Simple echo', () ->
    echo = null
    channel = null

    beforeEach () ->
      echo = new EchoChannel()
      channel = new DataChannel(echo)

    it 'should be able to send and receive', () ->
      return simple_echo_test(channel)

    it 'should receive data sent before being connected', () ->
      recv_data = []

      echo.send("a")

      channel.on 'message', (data) -> recv_data.push(data)

      echo.send("b")

      return channel.connect().then () ->
        echo.send("c")
        recv_data.should.deep.equal(["a", "b", "c"])


  describe 'Errors', () ->

    it 'should retry on send errors', () ->
      # receives all sent data with half of the send()s failing
      class DisruptedChannel

        constructor: () ->
          @bufferedAmount = 0
          @readyState = 'open'
          @error_toggle = false

        send: (data) ->
          @error_toggle = not @error_toggle

          if @error_toggle
            throw new Error("not now!")
          else
            @onmessage({data: data})

      channel = new DataChannel(new DisruptedChannel())
      return simple_echo_test(channel)

    it 'should fail when channel is closed because of error', () ->
      # signals error after some attempts
      class FailingChannel
        constructor: (@attempts=20) ->
          @bufferedAmount = 0
          @readyState = 'open'

        send: (data) ->
          @attempts -= 1

          if @attempts == 0
            @readyState = 'closed'
            @onerror(new Error("We failed"))

          throw new Error("not now!")

      rtc = new FailingChannel()
      channel = new DataChannel(rtc)

      return channel.connect().then () ->
        return Promise.all([
          channel.send('a').should.be.rejectedWith(Error)
          channel.send('b').should.be.rejectedWith(Error)
          channel.send('c').should.be.rejectedWith(Error)
        ])

  describe 'Buffer', () ->
    it 'should send and receive without exceeding buffer size', () ->
      # a channel which echos after some time and handles @bufferedAmount
      class BufferingChannel
        constructor: (@max_buffer) ->
          @bufferedAmount = 0
          @readyState = 'open'
          @buffer_respected = true

        send: (data) ->
          if @bufferedAmount > @max_buffer
            @buffer_respected = false

          @bufferedAmount += data.length

          setTimeout () =>
            @bufferedAmount -= data.length
            @onmessage({data: data})
          , 3

      max_buffer = 1

      rtc = new BufferingChannel(max_buffer)
      channel = new DataChannel(rtc, max_buffer)

      recv_data = []

      channel.on 'message', (data) -> recv_data.push(data)

      channel.connect().then () ->
        return Promise.all([
          channel.send('hello')
          channel.send('world')
          channel.send('!')
        ])
      .then () ->
        # TODO: this is not very scientific ;)
        new Promise (resolve) -> setTimeout(resolve, 10)
      .then () ->
        rtc.buffer_respected.should.be.true
        recv_data.should.deep.equal(['hello', 'world', '!'])

