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

	"hawx.me/code/retro/database"
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
	retroId string
	stage   string
	server  *sock.Server
	db      *database.Database

	mu    sync.RWMutex
	users map[string]string
}

func NewRoom(retroId string, db *database.Database) *Room {
	room := &Room{
		retroId: retroId,
		db:      db,
		server:  sock.NewServer(),
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
	r.db.EnsureUser(database.User{
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

		columns, _ := r.db.GetColumns(r.retroId)
		for _, column := range columns {
			conn.Send("", "column", columnData{column.Id, column.Name})

			cards, _ := r.db.GetCards(column.Id)
			for _, card := range cards {
				conn.Send("", "card", cardData{column.Id, card.Id, card.Revealed, card.Votes})

				contents, _ := r.db.GetContents(card.Id)
				for _, content := range contents {
					conn.Send(content.Author, "content", contentData{column.Id, card.Id, content.Text})
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

		card := database.Card{
			Id:       strId(),
			Column:   args.ColumnId,
			Votes:    0,
			Revealed: false,
		}

		r.db.AddCard(card)

		content := database.Content{
			Id:     strId(),
			Card:   card.Id,
			Text:   args.CardText,
			Author: conn.Name,
		}

		r.db.AddContent(content)

		conn.Broadcast("", "card", cardData{args.ColumnId, card.Id, card.Revealed, card.Votes})

		conn.Broadcast(content.Author, "content", contentData{args.ColumnId, content.Card, content.Text})
	})

	mux.Handle("move", func(conn *sock.Conn, data []byte) {
		var args moveData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.db.MoveCard(args.CardId, args.ColumnTo)

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

		r.db.RevealCard(args.CardId)

		conn.Broadcast(conn.Name, "reveal", args)
	})

	mux.Handle("group", func(conn *sock.Conn, data []byte) {
		var args groupData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		err := r.db.GroupCards(args.CardFrom, args.CardTo)
		if err != nil {
			log.Println(err)
		}

		conn.Broadcast(conn.Name, "group", args)
	})

	mux.Handle("vote", func(conn *sock.Conn, data []byte) {
		var args voteData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.db.VoteCard(args.CardId)

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

	db, err := database.Open("./db")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	retroId := "hey"

	db.EnsureRetro(database.Retro{
		Id: retroId,
	})

	db.EnsureColumn(database.Column{
		Id:    "0",
		Retro: retroId,
		Name:  "Start",
	})

	db.EnsureColumn(database.Column{
		Id:    "1",
		Retro: retroId,
		Name:  "More",
	})

	db.EnsureColumn(database.Column{
		Id:    "2",
		Retro: retroId,
		Name:  "Keep",
	})

	db.EnsureColumn(database.Column{
		Id:    "3",
		Retro: retroId,
		Name:  "Less",
	})

	db.EnsureColumn(database.Column{
		Id:    "4",
		Retro: retroId,
		Name:  "Stop",
	})

	room := NewRoom("hey", db)

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
