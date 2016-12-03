'use strict';

require('./index.html');
require('./styles.scss');
var Elm = require('./Main');

var app = Elm.Main.fullscreen();

app.ports.storageSet.subscribe(function([key, value]) {
  localStorage.setItem(key, value);
});

app.ports.storageGet.subscribe(function(key) {
  const value = localStorage.getItem(key);
  app.ports.storageGot.send(value);
});
