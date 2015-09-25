$(function() {
    // create a room
    var room = new rtc.Room("12345test", 'ws://ladon.local:8080');

    // create and display local video/audio
    var stream = room.local.addStream();
    var ve = new rtc.MediaDomElement($('#self'), stream);
    ve.mute();

    // add a data channel

    room.local.addDataChannel();

    // create video for peers
    room.on('peer_joined', function(peer) {
        var view = $('<video>');
        $('body').append(view);
        var ve = new rtc.MediaDomElement(view, peer);

        peer.on('closed', function() {
            view.remove();
        });

        peer.channel().then(function(channel) {
            console.log("got the channel!");
            console.log(channel);
        }).catch(function(err) {
            console.log(err);
        });
    });

    // join the room
    room.join();
});
