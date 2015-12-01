# rtc-lib

## What is this?

This is a WebRTC client library/abstraction layer. It is inspired by
[palava-client](https://github.com/palavatv/palava-client) and attempts to
offer users and developers a better experience.

The design goals and principles are

* allow simple code for basic usage as well as complex usage scenarios
* hide complexity of WebRTC
* heavy use of Promises
* support for multiple Streams and DataChannels
* consistent handling of errors and success notifications

The library is still under development but should provide basic functionality.
If something does not work as expected please file a bug report.

## How to use this?

The central element of the library is a `Room`. Multiple users, which are called
`Peer`, can join a room and will create peer to peer connections to each other.
You can send audio/video data to the peers through this connection, this is
represented by a `Stream`, or send custom data using a `DataChannel`.

All streams added to the local peer using `addStream()` will be sent to all
peers which are in the room. If you want to send a stream only to specific peers
you can add them later using `addStream()` on the remote peer as soon as they
are encountered. The same applies to data channels.

Here is a simple example:

    // create a room
    var room = new rtc.Room("wss://rtc.innovailable.eu/testroom");

    // create a local stream from the users camera
    var stream = room.local.addStream();

    // display that stream
    var ve = new rtc.MediaDomElement($('video'), stream);

    // get notified whenever we meet a new peer
    room.on('peer_joined', function(peer) {
        // create a video tag for the peer
        var view = $('<video>');
        $('body').append(view);
        var ve = new rtc.MediaDomElement(view, peer);

        // remove the tag after peer left
        peer.on('left', function() {
            view.remove();
        });
    });

    // join the room
    room.connect();

This can be considered a minimal example implementing a multi user video chat.
For your own implementation you might want to have more control over the
workflow and handle errors.

For a more complex example have a look at the `example` folder. You can run this
code using `make example` which will create a server which includes everything
you need. Feel free to play around with this test code to get to know the API.

The complete API documentation is embedded as
[YUIDoc](http://yui.github.io/yuidoc/) in the source code. You can create an
HTML page from it using `make doc` or view it online
[here](http://innovailable.github.io/rtc-lib/).

## What else do I need?

You will need a signaling server to enable the peers to find each other and
establish the peer to peer connections. The code is tested with
[easy-signaling](https://github.com/Innovailable/easy-signaling) which can be
run standalone or integrated as a node module. You could also write your own
signaling server or implement another signaling protocol.

It is also recommended to use a [STUN](https://en.wikipedia.org/wiki/STUN)
server which will allow peers to connect through routers and firewalls. If you
do not use one only clients on the same network would be able to connect to each
other. There are several STUN servers open for public use or you can set up your
own STUN server using one of multiple open source projects.

[TURN](https://en.wikipedia.org/wiki/Traversal_Using_Relays_around_NAT) servers
are currently not supported by this library.

