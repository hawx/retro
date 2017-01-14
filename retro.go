package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/google/uuid"

	"hawx.me/code/retro/data"
	"hawx.me/code/retro/models"
	"hawx.me/code/retro/sock"
	"hawx.me/code/serve"

	"golang.org/x/oauth2"
)

func strId() string {
	id, _ := uuid.NewRandom()
	return id.String()
}

type msg struct {
	Id   string   `json:"id"`
	Op   string   `json:"op"`
	Args []string `json:"args"`
}

type errorData struct {
	Error string `json:"error"`
}

type stageData struct {
	Stage string `json:"stage"`
}

type columnData struct {
	ColumnId   string `json:"columnId"`
	ColumnName string `json:"columnName"`
}

type cardData struct {
	ColumnId string `json:"columnId"`
	CardId   string `json:"cardId"`
	Revealed bool   `json:"revealed"`
	Votes    int    `json:"votes"`
}

type contentData struct {
	ColumnId string `json:"columnId"`
	CardId   string `json:"cardId"`
	CardText string `json:"cardText"`
}

type moveData struct {
	ColumnFrom string `json:"columnFrom"`
	ColumnTo   string `json:"columnTo"`
	CardId     string `json:"cardId"`
}

type revealData struct {
	ColumnId string `json:"columnId"`
	CardId   string `json:"cardId"`
}

type groupData struct {
	ColumnFrom string `json:"columnFrom"`
	CardFrom   string `json:"cardFrom"`
	ColumnTo   string `json:"columnTo"`
	CardTo     string `json:"cardTo"`
}

type voteData struct {
	ColumnId string `json:"columnId"`
	CardId   string `json:"cardId"`
}

type Room struct {
	stage  string
	server *sock.Server
	retro  *models.Retro
	db     *data.Database

	mu    sync.RWMutex
	users map[string]string
}

func NewRoom(db *data.Database) *Room {
	room := &Room{
		db:     db,
		server: sock.NewServer(),
		retro:  models.NewRetro(),
	}

	registerHandlers(room, room.server)

	return room
}

func boolToString(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func (r *Room) AddUser(user, token string) {
	r.db.EnsureUser(data.User{
		Username: user,
		Token:    token,
	})
}

func (r *Room) IsUser(user, token string) bool {
	found, err := r.db.GetUser(user)

	return err == nil && found.Token == token
}

func registerHandlers(r *Room, mux *sock.Server) {
	mux.Handle("init", func(conn *sock.Conn, data []byte) {
		var args struct {
			Name  string
			Token string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			log.Println("init:", err)
			return
		}

		conn.Name = args.Name

		if !r.IsUser(args.Name, args.Token) {
			conn.Err = errors.New("User not recognised: " + conn.Name)
			conn.Send("", "error", errorData{"unknown_user"})

			return
		}

		if r.stage != "" {
			conn.Send("", "stage", stageData{r.stage})
		}

		for _, column := range r.retro.Columns() {
			conn.Send("", "column", columnData{column.Id, column.Name})

			for cardId, card := range column.Cards() {
				conn.Send("", "card", cardData{column.Id, cardId, card.Revealed, card.Votes})

				for _, content := range card.Contents() {
					conn.Send(content.Author, "content", contentData{column.Id, cardId, content.Text})
				}
			}
		}
	})

	mux.Handle("add", func(conn *sock.Conn, data []byte) {
		var args struct {
			ColumnId string
			CardText string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			log.Println("add:", err)
			return
		}

		content := models.Content{
			Text:   args.CardText,
			Author: conn.Name,
		}

		card := &models.Card{
			Id:       strId(),
			Votes:    0,
			Revealed: false,
		}

		card.Add(content)

		r.retro.Get(args.ColumnId).Add(card)

		conn.Broadcast("", "card", cardData{args.ColumnId, card.Id, card.Revealed, card.Votes})

		conn.Broadcast(content.Author, "content", contentData{args.ColumnId, card.Id, content.Text})
	})

	mux.Handle("move", func(conn *sock.Conn, data []byte) {
		var args moveData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		target := r.retro.GetCard(args.ColumnFrom, args.CardId)

		r.retro.Get(args.ColumnTo).Add(target)
		r.retro.Get(args.ColumnFrom).Remove(args.CardId)

		conn.Broadcast(conn.Name, "move", args)
	})

	mux.Handle("stage", func(conn *sock.Conn, data []byte) {
		var args stageData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.stage = args.Stage

		conn.Broadcast(conn.Name, "stage", args)
	})

	mux.Handle("reveal", func(conn *sock.Conn, data []byte) {
		var args revealData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.retro.GetCard(args.ColumnId, args.CardId).Revealed = true

		conn.Broadcast(conn.Name, "reveal", args)
	})

	mux.Handle("group", func(conn *sock.Conn, data []byte) {
		var args groupData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		from := r.retro.GetCard(args.ColumnFrom, args.CardFrom)
		to := r.retro.GetCard(args.ColumnTo, args.CardTo)

		to.Votes += from.Votes
		r.retro.Get(args.ColumnFrom).Remove(args.CardFrom)

		for _, content := range from.Contents() {
			to.Add(content)
		}

		conn.Broadcast(conn.Name, "group", args)
	})

	mux.Handle("vote", func(conn *sock.Conn, data []byte) {
		var args voteData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.retro.GetCard(args.ColumnId, args.CardId).Votes += 1

		conn.Broadcast(conn.Name, "vote", args)
	})
}

func main() {
	var (
		clientID     = os.Getenv("GH_CLIENT_ID")
		clientSecret = os.Getenv("GH_CLIENT_SECRET")
		organisation = os.Getenv("ORGANISATION")

		port   = flag.String("port", "8080", "")
		socket = flag.String("socket", "", "")
		assets = flag.String("assets", "app/dist", "")
	)
	flag.Parse()

	db, err := data.Open("./db")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	room := NewRoom(db)
	room.retro.Add(models.NewColumn("0", "Start"))
	room.retro.Add(models.NewColumn("1", "More"))
	room.retro.Add(models.NewColumn("2", "Keep"))
	room.retro.Add(models.NewColumn("3", "Less"))
	room.retro.Add(models.NewColumn("4", "Stop"))

	http.Handle("/", http.FileServer(http.Dir(*assets)))

	http.Handle("/ws", room.server)

	ctx := context.Background()
	conf := &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Scopes:       []string{"user", "read:org"},
		Endpoint: oauth2.Endpoint{
			AuthURL:  "https://github.com/login/oauth/authorize",
			TokenURL: "https://github.com/login/oauth/access_token",
		},
	}

	http.HandleFunc("/oauth/login", func(w http.ResponseWriter, r *http.Request) {
		url := conf.AuthCodeURL("state", oauth2.AccessTypeOnline)

		http.Redirect(w, r, url, http.StatusFound)
	})

	http.HandleFunc("/oauth/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.FormValue("code")

		tok, err := conf.Exchange(ctx, code)
		if err != nil {
			log.Println(err)
			return
		}

		client := conf.Client(ctx, tok)

		user, err := getUser(client)
		if err != nil {
			log.Println(err)
			return
		}

		inOrg, err := isInOrg(client, organisation)
		if err != nil {
			log.Println(err)
			return
		}

		if inOrg {
			token := strId()
			room.AddUser(user, token)

			http.Redirect(w, r, "/?user="+user+"&token="+token, http.StatusFound)
		} else {
			http.Redirect(w, r, "/?error=not_in_org", http.StatusFound)
		}
	})

	serve.Serve(*port, *socket, http.DefaultServeMux)
}

func getUser(client *http.Client) (string, error) {
	resp, err := client.Get("https://api.github.com/user")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var data struct {
		Login string `json:"login"`
	}
	if err = json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return "", err
	}

	return data.Login, nil
}

func isInOrg(client *http.Client, expectedOrg string) (bool, error) {
	resp, err := client.Get("https://api.github.com/user/orgs")
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	var data []struct {
		Login string `json:"login"`
	}
	if err = json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return false, err
	}

	for _, org := range data {
		if org.Login == expectedOrg {
			return true, nil
		}
	}

	return false, nil
}
