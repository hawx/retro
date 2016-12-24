'use strict';

require('./index.html');
require('./styles.scss');
var Elm = require('./Main');

var qs = window.location.search.substring(1).split('&').reduce(function (a, e) {
  var parts = e.split('=');
  a[parts[0]] = parts[1];
  return a;
}, {});

if (qs['user']) {
  localStorage.setItem('id', qs['user']);
  window.location.search = '';
}

var app = Elm.Main.fullscreen();

app.ports.storageSet.subscribe(function([key, value]) {
  localStorage.setItem(key, value);
});

app.ports.storageGet.subscribe(function(key) {
  const value = localStorage.getItem(key);
  app.ports.storageGot.send(value);
});
