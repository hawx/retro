'use strict';

require('./index.html');
require('./styles.scss');
// var Elm = require('./src/Main');

// var qs = window.location.search.substring(1).split('&').reduce(function (a, e) {
//   var parts = e.split('=');
//   a[parts[0]] = parts[1];
//   return a;
// }, {});

// if (qs['token']) {
//   localStorage.setItem('idToken', qs['token']);
//   window.location.search = '';
// }

// var app = Elm.Main.fullscreen({
//   host: window.location.host,
//   isSecure: window.location.protocol === 'https:'
// });

// app.ports.signOut.subscribe(function() {
//   localStorage.removeItem('idToken');
//   window.location.reload();
// });

// app.ports.storageGet.subscribe(function(key) {
//   const value = localStorage.getItem(key);
//   app.ports.storageGot.send(value);
// });
