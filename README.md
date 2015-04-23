# rtc-lib

This is a prototype for a WebRTC client library/abstraction layer. It is heavily
inspired by [palava-client](https://github.com/palavatv/palava-client) and
attempts to offer users and developers a better experience.

Design goals:

* uses promises instead of events for fail/success notifications
* advanced signaling with information on which streams/datachannels should be
available
* support for multiple streams and renegotiation
* easier initialization
* improved signaling protocol

