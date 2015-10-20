$(function() {
    // construct websocket url from current location
    var loc = window.location;
    var signaling_url = 'ws://' + loc.hostname + ':' + loc.port + '/signaling';

    // create a room
    var room = new rtc.Room(signaling_url);

    // create and display local video/audio
    var stream = room.local.addStream();
    var ve = new rtc.MediaDomElement($('#self'), room.local);
    ve.mute();

    // create video for peers
    room.on('peer_joined', function(peer) {
        var view = $('<video>');
        $('body').append(view);
        var ve = new rtc.MediaDomElement(view, peer);
        ve.mute();

        console.log('peer joined!');

        peer.on('left', function() {
            view.remove();
        });

        peer.addDataChannel().then(function(channel) {
            console.log("got da channel!");
        }).catch(function(err) {
            console.log(err);
        });

        peer.connect();
    });

    room.on('closed', function() {
        $('body').html('Connection closed');
    });

    // join the room
    room.connect().then(function() { console.log('connected!'); });
});
