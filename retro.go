package main

import (
	"flag"
	"log"
	"net/http"

	"hawx.me/code/retro/auth"
	"hawx.me/code/retro/config"
	"hawx.me/code/retro/database"
	"hawx.me/code/retro/room"
	"hawx.me/code/serve"
)

func main() {
	var memoryPath = "file::memory:?mode=memory&cache=shared"
	var (
		configPath = flag.String("config", "config.toml", "")
		port       = flag.String("port", "8080", "")
		socket     = flag.String("socket", "", "")
		assets     = flag.String("assets", "app/dist", "")
		dbPath     = flag.String("db", "./db", "")
		test       = flag.Bool("test", false, "Run with test auth provider")
	)
	flag.Parse()

	conf, err := config.Read(*configPath)
	if err != nil {
		log.Fatal(err)
	}

	if *test {
		dbPath = &memoryPath
	}

	db, err := database.Open(*dbPath)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	room := room.New(room.Config{
		HasGitHub:    conf.GitHub != nil,
		HasOffice365: conf.Office365 != nil,
		HasTest:      *test,
	}, db)

	http.Handle("/", http.FileServer(http.Dir(*assets)))
	http.Handle("/ws", room.Server)

	if *test {
		testLogin, testCallback := auth.Test(room.AuthCallback)
		http.Handle("/oauth/test/login", testLogin)
		http.Handle("/oauth/test/callback", testCallback)
	}

	if conf.GitHub != nil {
		gitHubLogin, gitHubCallback := auth.GitHub(
			room.AuthCallback,
			conf.GitHub.ClientID,
			conf.GitHub.ClientSecret,
			conf.GitHub.Organisation)
		http.Handle("/oauth/github/login", gitHubLogin)
		http.Handle("/oauth/github/callback", gitHubCallback)
	}

	if conf.Office365 != nil {
		officeLogin, officeCallback := auth.Office365(
			room.AuthCallback,
			conf.Office365.ClientID,
			conf.Office365.ClientSecret,
			conf.Office365.Domain)
		http.Handle("/oauth/office365/login", officeLogin)
		http.Handle("/oauth/office365/callback", officeCallback)
	}

	serve.Serve(*port, *socket, http.DefaultServeMux)
}
