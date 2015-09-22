$(function() {
    var local = new rtc.LocalPeer({name: "Test0r"});
    var stream_p = local.addStream({audio: true, video: true});

    var room = new rtc.Room("12345test", 'wss://signaling.innovailable.eu', local, {stun: 'stun:sun.palava.tv'});

    room.on('peer_joined', function(peer) {
        console.log("peer joined");
        console.log(peer);
        peer.connect().then(function() {
            console.log("connected!");
        }).done();
    });

    stream_p.then(function(stream) {
        var ve = new rtc.MediaDomElement($('video'), stream);
        ve.mute();

        return room.join().then(function() {
            console.log('joined!');
        });
    }).done();
});
