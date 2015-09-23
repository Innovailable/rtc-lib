$(function() {
    // create a room
    var room = new rtc.Room("12345test", 'ws://ladon.local:8080');

    // create and display local video/audio
    var stream = room.local.addStream({audio: true, video: true});
    var ve = new rtc.MediaDomElement($('#self'), stream);
    ve.mute();

    // join the room
    room.join().done();

    // create video for peers
    room.on('peer_joined', function(peer) {
        console.log("new peer");
        var view = $('<video>');
        $('body').append(view);
        var ve = new rtc.MediaDomElement(view, peer);

        peer.on('closed', function() {
            view.remove();
        });
    });
});
