package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/SermoDigital/jose/crypto"
	"github.com/SermoDigital/jose/jws"
	"github.com/SermoDigital/jose/jwt"
	"github.com/google/uuid"
	"hawx.me/code/retro/auth"
	"hawx.me/code/retro/database"
	"hawx.me/code/retro/sock"
	"hawx.me/code/serve"
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
	ColumnId    string `json:"columnId"`
	ColumnName  string `json:"columnName"`
	ColumnOrder int    `json:"columnOrder"`
}

type cardData struct {
	ColumnId   string `json:"columnId"`
	CardId     string `json:"cardId"`
	Revealed   bool   `json:"revealed"`
	Votes      int    `json:"votes"`
	TotalVotes int    `json:"totalVotes"`
}

type contentData struct {
	ColumnId  string `json:"columnId"`
	CardId    string `json:"cardId"`
	ContentId string `json:"contentId"`
	CardText  string `json:"cardText"`
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
	UserId   string `json:"userId"`
	ColumnId string `json:"columnId"`
	CardId   string `json:"cardId"`
}

type deleteData struct {
	ColumnId string `json:"columnId"`
	CardId   string `json:"cardId"`
}

type userData struct {
	Username string `json:"username"`
}

type retroData struct {
	Id           string    `json:"id"`
	Name         string    `json:"name"`
	CreatedAt    time.Time `json:"createdAt"`
	Participants []string  `json:"participants"`
}

type Room struct {
	server *sock.Server
	db     *database.Database

	mu    sync.RWMutex
	users map[string]string
}

func NewRoom(db *database.Database) *Room {
	room := &Room{
		db:     db,
		server: sock.NewServer(),
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

func (r *Room) AddUser(user string) (string, error) {
	secret := strId()

	r.db.EnsureUser(database.User{
		Username: user,
		Token:    secret,
	})

	token, err := TokenForUser(user, secret)
	if err != nil {
		return "", err
	}
	return string(token), err
}

func (r *Room) IsUser(user, token string) bool {
	found, err := r.db.GetUser(user)

	parsedToken, err := jws.ParseJWT([]byte(token))
	if err != nil {
		return false
	}

	return VerifyTokenIsForUser(user, found.Token, parsedToken)
}

func VerifyTokenIsForUser(username, secret string, token jwt.JWT) bool {
	validator := jwt.Validator{}
	validator.SetAudience("retro.hawx.me")
	validator.SetSubject(username)

	return validator.Validate(token) == nil
}

func TokenForUser(username, secret string) ([]byte, error) {
	claims := jws.Claims{}
	claims.SetAudience("retro.hawx.me")
	claims.SetSubject(username)

	return jws.NewJWT(claims, crypto.SigningMethodHS256).Serialize([]byte(secret))
}

func registerHandlers(r *Room, mux *sock.Server) {
	mux.Auth(func(auth sock.MsgAuth) bool {
		return r.IsUser(auth.Username, auth.Token)
	})

	mux.Handle("joinRetro", func(conn *sock.Conn, data []byte) {
		var args struct {
			RetroId string
		}
		if err := json.Unmarshal(data, &args); err != nil {
			log.Println("joinRetro:", err)
			return
		}

		retro, err := r.db.GetRetro(args.RetroId)
		if err != nil {
			log.Println("joinRetro", args.RetroId, err)
			return
		}
		conn.RetroId = args.RetroId

		if retro.Stage != "" {
			conn.Send("", "stage", stageData{retro.Stage})
		}

		columns, err := r.db.GetColumns(args.RetroId)
		if err != nil {
			log.Println("columns", err)
			return
		}
		for _, column := range columns {
			conn.Send("", "column", columnData{column.Id, column.Name, column.Order})

			cards, err := r.db.GetCards(conn.Name, column.Id)
			if err != nil {
				log.Println(err)
			}
			for _, card := range cards {
				conn.Send("", "card", cardData{column.Id, card.Id, card.Revealed, card.Votes, card.TotalVotes})

				contents, _ := r.db.GetContents(card.Id)
				for _, content := range contents {
					conn.Send(content.Author, "content", contentData{column.Id, card.Id, content.Id, content.Text})
				}
			}
		}
	})

	mux.Handle("menu", func(conn *sock.Conn, data []byte) {
		users, err := r.db.GetUsers()
		if err != nil {
			log.Println("users", err)
			return
		}
		for _, user := range users {
			conn.Send("", "user", userData{user.Username})
		}

		retros, err := r.db.GetRetros(conn.Name)
		if err != nil {
			log.Println("retros", err)
			return
		}
		for _, retro := range retros {
			participants, err := r.db.GetParticipants(retro.Id)
			if err != nil {
				log.Println("retros.participants", err)
				continue
			}

			conn.Send("", "retro", retroData{retro.Id, retro.Name, retro.CreatedAt, participants})
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
			Revealed: false,
		}

		if err := r.db.AddCard(card); err != nil {
			log.Println("add db:", err)
			return
		}

		content := database.Content{
			Id:     strId(),
			Card:   card.Id,
			Text:   args.CardText,
			Author: conn.Name,
		}

		if err := r.db.AddContent(content); err != nil {
			log.Println("add db:", err)
			return
		}

		conn.Broadcast("", "card", cardData{args.ColumnId, card.Id, card.Revealed, card.Votes, card.TotalVotes})

		conn.Broadcast(content.Author, "content", contentData{args.ColumnId, content.Card, content.Id, content.Text})
	})

	mux.Handle("edit", func(conn *sock.Conn, data []byte) {
		var content contentData
		if err := json.Unmarshal(data, &content); err != nil {
			log.Println("add:", err)
			return
		}

		if err := r.db.UpdateContent(content.ContentId, content.CardText); err != nil {
			log.Println("update db:", err)
			return
		}

		conn.Broadcast(conn.Name, "content", content)
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

		r.db.SetStage(conn.RetroId, args.Stage)

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

		args.UserId = conn.Name
		r.db.Vote(conn.Name, args.CardId)

		conn.Broadcast(conn.Name, "vote", args)
	})

	mux.Handle("unvote", func(conn *sock.Conn, data []byte) {
		var args voteData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		args.UserId = conn.Name
		r.db.Unvote(conn.Name, args.CardId)

		conn.Broadcast(conn.Name, "unvote", args)
	})

	mux.Handle("delete", func(conn *sock.Conn, data []byte) {
		var args deleteData
		if err := json.Unmarshal(data, &args); err != nil {
			return
		}

		r.db.DeleteCard(args.CardId)

		conn.Broadcast(conn.Name, "delete", args)
	})

	mux.Handle("createRetro", func(conn *sock.Conn, data []byte) {
		var args struct {
			Name  string   `json:"name"`
			Users []string `json:"users"`
		}

		if err := json.Unmarshal(data, &args); err != nil {
			log.Println(err)
			return
		}

		retroId := strId()
		createdAt := time.Now()

		r.db.AddRetro(database.Retro{
			Id:        retroId,
			Name:      args.Name,
			Stage:     "",
			CreatedAt: createdAt,
		})

		r.db.AddColumn(database.Column{
			Id:    strId(),
			Retro: retroId,
			Name:  "Start",
			Order: 0,
		})

		r.db.AddColumn(database.Column{
			Id:    strId(),
			Retro: retroId,
			Name:  "More",
			Order: 1,
		})

		r.db.AddColumn(database.Column{
			Id:    strId(),
			Retro: retroId,
			Name:  "Keep",
			Order: 2,
		})

		r.db.AddColumn(database.Column{
			Id:    strId(),
			Retro: retroId,
			Name:  "Less",
			Order: 3,
		})

		r.db.AddColumn(database.Column{
			Id:    strId(),
			Retro: retroId,
			Name:  "Stop",
			Order: 4,
		})

		allParticipants := append(args.Users, conn.Name)

		for _, user := range allParticipants {
			r.db.AddParticipant(retroId, user)
		}

		conn.Send(conn.Name, "retro", retroData{retroId, args.Name, createdAt, allParticipants})
	})
}

type config struct {
	GitHub    gitHubConfig    `toml:"github"`
	Office365 office365Config `toml:"office365"`
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

	room := NewRoom(db)

	conf := config{}
	if _, err := toml.DecodeFile(*configPath, &conf); err != nil {
		log.Fatal(err)
	}

	http.Handle("/", http.FileServer(http.Dir(*assets)))
	http.Handle("/ws", room.server)

	gitHubLogin, gitHubCallback := auth.GitHub(
		room.AddUser,
		conf.GitHub.ClientID,
		conf.GitHub.ClientSecret,
		conf.GitHub.Organisation)
	http.Handle("/oauth/github/login", gitHubLogin)
	http.Handle("/oauth/github/callback", gitHubCallback)

	officeLogin, officeCallback := auth.Office365(room.AddUser,
		conf.Office365.ClientID,
		conf.Office365.ClientSecret,
		conf.Office365.Domain)
	http.Handle("/oauth/office365/login", officeLogin)
	http.Handle("/oauth/office365/callback", officeCallback)

	serve.Serve(*port, *socket, http.DefaultServeMux)
}
