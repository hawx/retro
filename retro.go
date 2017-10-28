package main

import (
	"flag"
	"log"
	"net/http"

	"github.com/BurntSushi/toml"
	"hawx.me/code/retro/auth"
	"hawx.me/code/retro/database"
	"hawx.me/code/retro/room"
	"hawx.me/code/serve"
)

type config struct {
	GitHub    *gitHubConfig    `toml:"github"`
	Office365 *office365Config `toml:"office365"`
}

type gitHubConfig struct {
	ClientID     string `toml:"clientID"`
	ClientSecret string `toml:"clientSecret"`
	Organisation string `toml:"organisation"`
}

type office365Config struct {
	ClientID     string `toml:"clientID"`
	ClientSecret string `toml:"clientSecret"`
	Domain       string `toml:"domain"`
}

func main() {
	var (
		configPath = flag.String("config", "config.toml", "")
		port       = flag.String("port", "8080", "")
		socket     = flag.String("socket", "", "")
		assets     = flag.String("assets", "app/dist", "")
		dbPath     = flag.String("db", "./db", "")
	)
	flag.Parse()

	db, err := database.Open(*dbPath)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	room := room.New(db)

	conf := config{}
	if _, err := toml.DecodeFile(*configPath, &conf); err != nil {
		log.Fatal(err)
	}

	http.Handle("/", http.FileServer(http.Dir(*assets)))
	http.Handle("/ws", room.Server)

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
