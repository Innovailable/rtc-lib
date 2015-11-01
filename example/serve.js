var express = require('express');
var es = require('easy-signaling');
var path = require('path');

var app = express();

// serve all files in the project directory

app.use(express.static(__dirname + '/..'));

// redirect from root to test page

app.get('/', function(req, res) {
    res.redirect('/example/test.html');
});

// integrate signaling server

var room = new es.Room();

require('express-ws')(app);
app.ws('/signaling', function(ws) {
    var channel = new es.WebsocketChannel(ws);
    room.create_guest(channel);
});

// start server

var server = app.listen(8080, function() {
    var host = server.address().address;
    var port = server.address().port;

    console.log('Example app listening at http://%s:%s', host, port);
});
