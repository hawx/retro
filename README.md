# retro

![](https://travis-ci.org/hawx/retro.svg?branch=master)

A webapp for running (remote) retrospectives.

## Install

You will need [NodeJS](https://nodejs.org) and [Go](https://golang.org) installed, then you should be able to

```sh
$ go get hawx.me/code/retro
$ cd $GOPATH/src/hawx.me/code/retro
$ make install
```

## Configuration

Retro reads configuration from a `config.toml` file, so create one.

To authenticate by GitHub against a particular organisation you will need to
[setup an application](https://github.com/settings/developers) with the
"Authorization callback URL" of <http://localhost:8080/oauth/github/callback>
(substitute the place you will host retro for http://localhost:8080). Then add
the following to your `config.toml`.

```
[github]
clientID = "..."
clientSecret = "..."
organisation = "..."
```

To authenticate by Office365 against a particular domain you will need to [setup
an application](https://apps.dev.microsoft.com/) with the "Redirect URLs" of
<http://localhost:8080/oauth/office365/callback> (substitute the place you will
host retro for http://localhost:8080). Then add the following to your
`config.toml`.

```
[office365]
clientID = "..."
clientSecret = "..."
domain = "..."
```

## Build and test

Build and test with make,

```
$ make
$ make test
```

The build step puts everything in `./out`, so you can run retro from that folder too

```sh
$ cd out
$ retro
```

This will run the app at <http://localhost:8080> by default (this can be changed
by passing `--port` or using `--socket`).
