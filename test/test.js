$(function() {
    var room = new rtc.Room("12345test", 'wss://signaling.innovailable.eu');
    var stream_p = room.local.addStream({audio: true, video: true});

    room.on('peer_joined', function(peer) {
        console.log("peer joined");
        console.log(peer);

        peer.connect().then(function() {
            console.log("connected!");
        }).done();

        peer.stream().then(function(stream) {
            var ve = new rtc.MediaDomElement($('#remote'), stream);
            ve.mute();
        }).done;
    });

    stream_p.then(function(stream) {
        var ve = new rtc.MediaDomElement($('#self'), stream);
        ve.mute();

        return room.join().then(function() {
            console.log('joined!');
        });
    }).done();
});
