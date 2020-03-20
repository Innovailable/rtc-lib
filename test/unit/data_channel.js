/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const {DataChannel} = require('../../src/data_channel');

// receives all sent data
class EchoChannel {

  constructor() {
    this.bufferedAmount = 0;
    this.readyState = 'open';
  }

  send(data) {
    return this.onmessage({data});
  }
}

// sends some data and checks whether it is received
const simple_echo_test = function(channel, send_data) {
  if (send_data == null) { send_data = ['test', 'me', 'please']; }
  const recv_data = [];

  channel.on('message', data => recv_data.push(data));

  return channel.connect().then(function() {
    const promises = [];

    for (let data of Array.from(send_data)) {
      const p = channel.send(data);
      promises.push(p);
    }

    return Promise.all(promises);}).then(() => recv_data.should.deep.equal(send_data));
};


describe('DataChannel', function() {
  describe('Simple echo', function() {
    let echo = null;
    let channel = null;

    beforeEach(function() {
      echo = new EchoChannel();
      return channel = new DataChannel(echo);
    });

    it('should be able to send and receive', () => simple_echo_test(channel));

    return it('should receive data sent before being connected', function() {
      const recv_data = [];

      echo.send("a");

      channel.on('message', data => recv_data.push(data));

      echo.send("b");

      return channel.connect().then(function() {
        echo.send("c");
        return recv_data.should.deep.equal(["a", "b", "c"]);
      });
    });
  });


  describe('Errors', function() {

    it('should retry on send errors', function() {
      // receives all sent data with half of the send()s failing
      class DisruptedChannel {

        constructor() {
          this.bufferedAmount = 0;
          this.readyState = 'open';
          this.error_toggle = false;
        }

        send(data) {
          this.error_toggle = !this.error_toggle;

          if (this.error_toggle) {
            throw new Error("not now!");
          } else {
            return this.onmessage({data});
          }
        }
      }

      const channel = new DataChannel(new DisruptedChannel());
      return simple_echo_test(channel);
    });

    return it('should fail when channel is closed because of error', function() {
      // signals error after some attempts
      class FailingChannel {
        constructor(attempts) {
          if (attempts == null) { attempts = 20; }
          this.attempts = attempts;
          this.bufferedAmount = 0;
          this.readyState = 'open';
        }

        send(data) {
          this.attempts -= 1;

          if (this.attempts === 0) {
            this.readyState = 'closed';
            this.onerror(new Error("We failed"));
          }

          throw new Error("not now!");
        }
      }

      const rtc = new FailingChannel();
      const channel = new DataChannel(rtc);

      return channel.connect().then(() => Promise.all([
        channel.send('a').should.be.rejectedWith(Error),
        channel.send('b').should.be.rejectedWith(Error),
        channel.send('c').should.be.rejectedWith(Error)
      ]));
    });
  });

  return describe('Buffer', () => it('should send and receive without exceeding buffer size', function() {
    // a channel which echos after some time and handles @bufferedAmount
    class BufferingChannel {
      constructor(max_buffer1) {
        this.max_buffer = max_buffer1;
        this.bufferedAmount = 0;
        this.readyState = 'open';
        this.buffer_respected = true;
      }

      send(data) {
        if (this.bufferedAmount > this.max_buffer) {
          this.buffer_respected = false;
        }

        this.bufferedAmount += data.length;

        return setTimeout(() => {
          this.bufferedAmount -= data.length;
          return this.onmessage({data});
        }
        , 3);
      }
    }

    const max_buffer = 1;

    const rtc = new BufferingChannel(max_buffer);
    const channel = new DataChannel(rtc, max_buffer);

    const recv_data = [];

    channel.on('message', data => recv_data.push(data));

    return channel.connect().then(() => Promise.all([
      channel.send('hello'),
      channel.send('world'),
      channel.send('!')
    ])).then(() => // TODO: this is not very scientific ;)
    new Promise(resolve => setTimeout(resolve, 10))).then(function() {
      rtc.buffer_respected.should.be.true;
      return recv_data.should.deep.equal(['hello', 'world', '!']);
    });
  }));
});

