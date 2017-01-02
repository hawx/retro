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

type Room struct {
	stage  string
	server *sock.Server
	retro  *models.Retro

	mu    sync.RWMutex
	users map[string]string
}

func NewRoom() *Room {
	room := &Room{
		server: sock.NewServer(),
		retro:  models.NewRetro(),
		users:  map[string]string{},
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
	r.mu.Lock()
	r.users[user] = token
	r.mu.Unlock()
}

func (r *Room) IsUser(user, token string) bool {
	r.mu.RLock()
	expectedToken, ok := r.users[user]
	r.mu.RUnlock()
	return ok && token == expectedToken
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

			conn.Send("", "error", struct {
				Error string `json:"error"`
			}{"unknown_user"})

			return
		}

		if r.stage != "" {
			conn.Send("", "stage", struct {
				Stage string `json:"stage"`
			}{r.stage})
		}

		for _, column := range r.retro.Columns() {
			conn.Send("", "column", struct {
				ColumnId   string `json:"columnId"`
				ColumnName string `json:"columnName"`
			}{column.Id, column.Name})

			for cardId, card := range column.Cards() {
				conn.Send("", "card", struct {
					ColumnId string `json:"columnId"`
					CardId   string `json:"cardId"`
					Revealed bool   `json:"revealed"`
					Votes    int    `json:"votes"`
				}{column.Id, cardId, card.Revealed, card.Votes})

				for _, content := range card.Contents() {
					conn.Send(content.Author, "content", struct {
						ColumnId string `json:"columnId"`
						CardId   string `json:"cardId"`
						CardText string `json:"cardText"`
					}{column.Id, cardId, content.Text})
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

		conn.Broadcast("", "card", struct {
			ColumnId string `json:"columnId"`
			CardId   string `json:"cardId"`
			Revealed bool   `json:"revealed"`
			Votes    int    `json:"votes"`
		}{args.ColumnId, card.Id, card.Revealed, card.Votes})

		conn.Broadcast(content.Author, "content", struct {
			ColumnId string `json:"columnId"`
			CardId   string `json:"cardId"`
			CardText string `json:"cardText"`
		}{args.ColumnId, card.Id, content.Text})
	})

	mux.Handle("move", func(conn *sock.Conn, data []byte) {
		var args struct {
			ColumnFrom string
			ColumnTo   string
			CardId     string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		target := r.retro.GetCard(args.ColumnFrom, args.CardId)

		r.retro.Get(args.ColumnTo).Add(target)
		r.retro.Get(args.ColumnFrom).Remove(args.CardId)

		conn.Broadcast(conn.Name, "move", struct {
			ColumnFrom string `json:"columnFrom"`
			ColumnTo   string `json:"columnTo"`
			CardId     string `json:"cardId"`
		}{args.ColumnFrom, args.ColumnTo, args.CardId})
	})

	mux.Handle("stage", func(conn *sock.Conn, data []byte) {
		var args struct {
			Stage string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.stage = args.Stage

		conn.Broadcast(conn.Name, "stage", struct {
			Stage string `json:"stage"`
		}{args.Stage})
	})

	mux.Handle("reveal", func(conn *sock.Conn, data []byte) {
		var args struct {
			ColumnId string // shouldn't really need columnId
			CardId   string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.retro.GetCard(args.ColumnId, args.CardId).Revealed = true

		conn.Broadcast(conn.Name, "reveal", struct {
			ColumnId string `json:"columnId"`
			CardId   string `json:"cardId"`
		}{args.ColumnId, args.CardId})
	})

	mux.Handle("group", func(conn *sock.Conn, data []byte) {
		var args struct {
			ColumnFrom string
			CardFrom   string
			ColumnTo   string
			CardTo     string
		}
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

		conn.Broadcast(conn.Name, "group", struct {
			ColumnFrom string `json:"columnFrom"`
			CardFrom   string `json:"cardFrom"`
			ColumnTo   string `json:"columnTo"`
			CardTo     string `json:"cardTo"`
		}{args.ColumnFrom, args.CardFrom, args.ColumnTo, args.CardTo})
	})

	mux.Handle("vote", func(conn *sock.Conn, data []byte) {
		var args struct {
			ColumnId string
			CardId   string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.retro.GetCard(args.ColumnId, args.CardId).Votes += 1

		conn.Broadcast(conn.Name, "vote", struct {
			ColumnId string `json:"columnId"`
			CardId   string `json:"cardId"`
		}{args.ColumnId, args.CardId})
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

	room := NewRoom()
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
