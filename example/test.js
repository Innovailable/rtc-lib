$(document).ready(async function() {
    // construct websocket url from current location
    var loc = window.location;
    var signaling_url = 'ws://' + loc.hostname + ':' + loc.port + '/signaling';

    const channel = new rtc.WebSocketChannel(signaling_url);
    const signaling = new rtc.MucSignaling(channel);

    // use a poublic stun server
    const options = {
        stun: "stun:stun.innovailable.eu",
    }

    // create a room
    const room = new rtc.Room(signaling, options);

    // create a local stream from the users camera
    const stream = await room.local.addStream({ video: true, audio: true });

    // display that stream
    const ve = new rtc.MediaDomElement($('#self')[0], stream);

    // get notified whenever we meet a new peer
    room.on('peer_joined', function(peer) {
        // create a video tag for the peer
        const view = $('<video autoplay>');
        $('body').append(view);
        const ve = new rtc.MediaDomElement(view[0], peer);

        // remove the tag after peer left
        peer.on('left', function() {
            view.remove();
        });
    });

    // join the room
    try {
        await room.connect();
    } catch(err) {
        alert("Unable to join room: " + err.message)
    }
});
