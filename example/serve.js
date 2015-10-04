var express = require('express');
var es = require('easy-signaling');
var path = require('path');


var room = new es.Room();

app = express();

app.use(express.static(__dirname + '/..'));

require('express-ws')(app);
app.ws('/signaling', function(ws) {
    var channel = new es.WebsocketChannel(ws);
    room.create_guest(channel);
});

var server = app.listen(8080, function() {
    var host = server.address().address;
    var port = server.address().port;

    console.log('Example app listening at http://%s:%s', host, port);
});
