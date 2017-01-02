package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"strconv"
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

		if r.IsUser(args.Name, args.Token) {
			r.initOp(conn)
			return
		}

		conn.Err = errors.New("User not recognised: " + conn.Name)

		conn.Send(sock.Msg{
			Id:   "",
			Op:   "error",
			Args: []string{"unknown_user"},
		})
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

		r.addOp(conn, args.ColumnId, args.CardText)
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

		r.moveOp(conn, args.ColumnFrom, args.ColumnTo, args.CardId)
	})

	mux.Handle("stage", func(conn *sock.Conn, data []byte) {
		var args struct {
			Stage string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.stageOp(conn, args.Stage)
	})

	mux.Handle("reveal", func(conn *sock.Conn, data []byte) {
		var args struct {
			ColumnId string // shouldn't really need columnId
			CardId   string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.revealOp(conn, args.ColumnId, args.CardId)
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

		r.groupOp(conn, args.ColumnFrom, args.CardFrom, args.ColumnTo, args.CardTo)
	})

	mux.Handle("vote", func(conn *sock.Conn, data []byte) {
		var args struct {
			ColumnId string
			CardId   string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.voteOp(conn, args.ColumnId, args.CardId)
	})
}

func (r *Room) initOp(conn *sock.Conn) {
	if r.stage != "" {
		conn.Send(sock.Msg{
			Id:   "",
			Op:   "stage",
			Args: []string{r.stage},
		})
	}

	for _, column := range r.retro.Columns() {
		conn.Send(sock.Msg{
			Id:   "",
			Op:   "column",
			Args: []string{column.Id, column.Name},
		})

		for cardId, card := range column.Cards() {
			conn.Send(sock.Msg{
				Id:   "",
				Op:   "card",
				Args: []string{column.Id, cardId, boolToString(card.Revealed), strconv.Itoa(card.Votes)},
			})

			for _, content := range card.Contents() {
				conn.Send(sock.Msg{
					Id:   content.Author,
					Op:   "content",
					Args: []string{column.Id, cardId, content.Text},
				})
			}
		}
	}
}

func (r *Room) addOp(conn *sock.Conn, columnId, cardText string) {
	content := models.Content{
		Text:   cardText,
		Author: conn.Name,
	}

	card := &models.Card{
		Id:       strId(),
		Votes:    0,
		Revealed: false,
	}

	card.Add(content)

	r.retro.Get(columnId).Add(card)

	conn.Broadcast(sock.Msg{
		Id:   "",
		Op:   "card",
		Args: []string{columnId, card.Id, boolToString(card.Revealed), strconv.Itoa(card.Votes)},
	})

	conn.Broadcast(sock.Msg{
		Id:   content.Author,
		Op:   "content",
		Args: []string{columnId, card.Id, content.Text},
	})
}

func (r *Room) moveOp(conn *sock.Conn, columnFrom, columnTo, cardId string) {
	target := r.retro.GetCard(columnFrom, cardId)

	r.retro.Get(columnTo).Add(target)
	r.retro.Get(columnFrom).Remove(cardId)

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "move",
		Args: []string{columnFrom, columnTo, cardId},
	})
}

func (r *Room) stageOp(conn *sock.Conn, stage string) {
	r.stage = stage

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "stage",
		Args: []string{stage},
	})
}

func (r *Room) revealOp(conn *sock.Conn, columnId, cardId string) {
	r.retro.GetCard(columnId, cardId).Revealed = true

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "reveal",
		Args: []string{columnId, cardId},
	})
}

func (r *Room) groupOp(conn *sock.Conn, columnFrom, cardFrom, columnTo, cardTo string) {
	from := r.retro.GetCard(columnFrom, cardFrom)
	to := r.retro.GetCard(columnTo, cardTo)

	r.retro.Get(columnFrom).Remove(cardFrom)

	for _, content := range from.Contents() {
		to.Add(content)
	}

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "group",
		Args: []string{columnFrom, cardFrom, columnTo, cardTo},
	})
}

func (r *Room) voteOp(conn *sock.Conn, columnId, cardId string) {
	r.retro.GetCard(columnId, cardId).Votes += 1

	conn.Broadcast(sock.Msg{
		Id:   conn.Name,
		Op:   "vote",
		Args: []string{columnId, cardId},
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
