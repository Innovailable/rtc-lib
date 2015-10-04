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

    // add a data channel to all incoming peers
    room.local.addDataChannel();

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

        peer.channel().then(function(channel) {
            console.log("got the channel!");
        }).catch(function(err) {
            console.log(err);
        });
    });

    // join the room
    room.connect().then(function() { console.log('connected!'); });
});
