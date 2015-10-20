# rtc-lib

## What is this?

This is a WebRTC client library/abstraction layer. It is inspired by
[palava-client](https://github.com/palavatv/palava-client) and attempts to
offer users and developers a better experience.

The design goals and principles are

* hide complexity of WebRTC
* allow simple code for basic usage as well as complex usage scenarios
* heavy use of `Promise`s
* support for multiple Streams and DataChannels
* consistent handling of errors and success notification

The library is still under development but should provide basic functionality.
If something does not work as expected please file a bug report.

## How to use this?

Here is a simple example using this library

    // create a room
    var room = new rtc.Room("wss://signaling.innovailable.eu/testroom");

    // create a local stream from the users camera
    var stream = room.local.addStream();

    // display that stream
    var ve = new rtc.MediaDomElement($('video'), stream);

    // create video for peers
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

The complete API documentation is embedded as YUIDoc in the source code. You can
create an HTML page from it using `make doc` or view it online
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

